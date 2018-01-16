import Async

enum StreamState {
    // Authenticating
    case start, sentSSL, sentHandshake, sentAuthentication
    
    // Idle states
    case nothing, closed
    
    case columnCount(AnyInputStream<Row>, binary: Bool)
    case columns(Int, AnyInputStream<Row>, binary: Bool, acceptsEOF: Bool)
    case rows(AnyInputStream<Row>, binary: Bool, acceptsEOF: Bool)
}

final class MySQLStateMachine: ConnectionContext {
    typealias Input = Task
    typealias Output = Packet
    
    let user: String
    let password: String?
    let database: String
    
    var state: StreamState {
        didSet {
            if case .nothing = state {
                self.columns = nil
                self.unprocessedPacket = nil
                self.downstreamDemand = 0
                executor.request()
            }
        }
    }
    
    /// The inserted ID from the last successful query
    public var lastInsertID: UInt64?
    
    /// Amount of affected rows in the last successful query
    public var affectedRows: UInt64?
    
    var handshake: Handshake?
    var sequenceId: UInt8
    var ssl: MySQLSSLConfig?
    var connected = Promise<Void>()
    var worker: Worker
    let parser: TranslatingStreamWrapper<MySQLPacketParser>
    let executor: PushStream<Task>
    let serializer: PushStream<Packet>
    let _serializer: MySQLPacketSerializer
    var downstreamDemand: UInt
    var unprocessedPacket: Packet?
    
    var columns: [Field]?
    
    init<S>(
        source: SocketSource<S>,
        sink: SocketSink<S>,
        user: String,
        password: String?,
        database: String,
        ssl: MySQLSSLConfig?,
        worker: Worker
    ) {
        self.state = .start
        self.parser = MySQLPacketParser().stream(on: worker)
        self.ssl = ssl
        self.sequenceId = 0
        self.worker = worker
        self.serializer = PushStream<Packet>()
        self.executor = PushStream<Task>()
        self._serializer = MySQLPacketSerializer()
        self.user = user
        self.password = password
        self.database = database
        self.downstreamDemand = 0

        source.stream(to: parser).drain { packet, upstream in
            do {
                try self.parse(packet: packet, upstream: upstream)
            } catch {
                self.error(error)
            }
        }.upstream?.request()
        
        self.serializer.stream(to: _serializer.stream(on: worker)).output(to: sink)
        
        self.executor.drain { task, _ in
            try self.process(task: task)
        }.upstream?.request()
    }
    
    func error(_ error: Error) {
        switch state {
        case .columnCount(let stream, _):
            stream.error(error)
            self.state = .nothing
        case .columns(_, let stream, _, _):
            stream.error(error)
            self.state = .nothing
        case .rows(let stream, _, _):
            stream.error(error)
            self.state = .nothing
        default: break
        }
    }
    
    func parse(packet: Packet, upstream: ConnectionContext) throws {
        switch state {
        case .start:
            // https://mariadb.com/kb/en/library/1-connecting-connecting/
            if  let ssl = self.ssl, capabilities.contains(.ssl) {
                _ = ssl
                fatalError("Unsupported StartTLS")
                // Do SSL upgrade
                // self.state = .sendSSL
            } else {
                state = .sentHandshake
                serializer.push(try doHandshake(from: packet))
                upstream.request()
            }
        case .sentSSL:
            // https://mariadb.com/kb/en/library/1-connecting-connecting/
            state = .sentHandshake
            serializer.push(try doHandshake(from: packet))
        case .sentHandshake:
            // https://mariadb.com/kb/en/library/1-connecting-connecting/
            
            guard let packet = try self.finishAuthentication(for: packet) else {
                state = .nothing
                self.connected.complete()
                return
            }
            
            state = .sentAuthentication
            serializer.push(packet)
        case .sentAuthentication:
            _ = try packet.parseBinaryOK()
            state = .nothing
        case .nothing:
            throw MySQLError(.unexpectedResponse)
        case .closed:
            throw MySQLError(.unexpectedResponse)
        case .columnCount(let results, let binary):
            var parser = Parser(packet: packet)
            let length = try parser.parseLenEnc()
            
            guard length < Int.max else {
                throw MySQLError(.unexpectedResponse)
            }
            
            if length == 0 {
                defer { results.close() }
                state = .nothing
                
                if let (affectedRows, lastInsertID) = try packet.parseBinaryOK() {
                    self.affectedRows = affectedRows
                    self.lastInsertID = lastInsertID
                }
                
                return
            }
            
            state = .columns(numericCast(length), results, binary: binary, acceptsEOF: true)
            upstream.request()
        case .columns(let columns, let results, let binary, let acceptsEOF):
            if acceptsEOF {
                self.state = .columns(columns, results, binary: binary, acceptsEOF: false)
                
                if packet.payload.first == 0xfe {
                    let eof = try EOF(packet: packet)
                    
                    if eof.flags & EOF.serverMoreResultsExists == 0 {
                        results.close()
                        state = .nothing
                        return
                    }
                    
                    upstream.request()
                }
            }
            
            if self.columns == nil {
                self.columns = []
            }
            
            self.columns?.append(try packet.parseFieldDefinition())
        case .rows(let results, let binary, let acceptsEOF):
            if acceptsEOF {
                self.state = .rows(results, binary: binary, acceptsEOF: false)
                
                // If EOF
                if (try? EOF(packet: packet)) != nil {
                    upstream.request()
                }
            }
            
            guard let columns = self.columns else {
                throw MySQLError(identifier: "row-columns", reason: "The rows were being parsed but no columns were found")
                return
            }
            
            // End of Rows
            if packet.payload.first == 0xfe {
                results.close()
                state = .nothing
                return
            }
            
            if downstreamDemand > 0 {
                downstreamDemand -= 1
                let row = try packet.parseRow(columns: columns, binary: binary)
                results.next(row)
            } else {
                unprocessedPacket = packet
            }
        }
    }
    
    func connection(_ event: ConnectionEvent) {
        switch event {
        case .cancel:
            downstreamDemand = 0
        case .request(let amount):
            downstreamDemand += amount
        }
    }
    
    fileprivate func process(task: Task) throws {
        guard let packet = task.packet else {
            return
        }
        
        self.state = makeState(for: task)
        
        serializer.next(packet)
        parser.request()
    }
    
    func close(immediately: Bool = false) {
        if immediately {
            self.state = .closed
            self.serializer.close()
        } else {
            // Write `close`
            _ = send(.close)
            
            executor.close()
        }
    }
    
    func send(_ task: Task) {
        self.executor.next(task)
    }
    
    fileprivate func completeTask() {
        self.state = .nothing
        self.executor.request()
    }
    
    fileprivate func makeState(for task: Task) -> StreamState {
        switch task {
        case .close:
            return .closed
        case .textQuery(_, let stream):
            return .columnCount(stream, binary: false)
        case .none:
            return .nothing
        case .prepare:
            fatalError()
        }
    }
}

enum TaskResult {
    case none
}

struct EOF {
    var flags: UInt16
    
    static let serverMoreResultsExists: UInt16 = 0x0008
    
    init(packet: Packet) throws {
        var parser = Parser(packet: packet)
        
        guard try parser.byte() == 0xfe, packet.payload.count == 5 else {
            throw MySQLError(.invalidPacket)
        }
        
        self.flags = try parser.parseUInt16()
    }
}

enum Task {
    case close
    case textQuery(String, AnyInputStream<Row>)
    case prepare(String)
    case none
    
    var packet: Packet? {
        switch self {
        case .close:
            return [0x01]
        case .textQuery(let query, _):
            return Packet(data: [0x03] + Array(query.utf8))
        case .prepare(let query):
            return Packet(data: [0x16] + Array(query.utf8))
        case .none:
            return nil
        }
    }
}
