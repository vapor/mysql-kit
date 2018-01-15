import Async

final class MySQLStateMachine {
    enum StreamState {
        case nothing, closed
        case textQuerySent(TranslatingStreamWrapper<RowParser>)
    }
    
    typealias Input = Task
    typealias Output = Packet
    
    let user: String
    let password: String?
    let database: String
    
    var state: StreamState
    var currentTask: Task
    var handshake: Handshake?
    var sequenceId: UInt8
    var ssl: MySQLSSLConfig?
    var connected = Promise<Void>()
    var connectionState: ConnectionState
    var worker: Worker
    let parser: TranslatingStreamWrapper<MySQLPacketParser>
    let executor: PushStream<Task>
    let serializer: PushStream<Packet>
    let _serializer: MySQLPacketSerializer
    let delta: DeltaStream<Packet>
    
    init<S>(
        source: SocketSource<S>,
        sink: SocketSink<S>,
        user: String,
        password: String?,
        database: String,
        ssl: MySQLSSLConfig?,
        worker: Worker
    ) {
        self.state = .nothing
        self.parser = MySQLPacketParser().stream(on: worker)
        self.ssl = ssl
        self.sequenceId = 0
        self.currentTask = .none
        self.connectionState = .start
        self.worker = worker
        self.serializer = PushStream<Packet>()
        self.executor = PushStream<Task>()
        self._serializer = MySQLPacketSerializer()
        self.user = user
        self.password = password
        self.database = database
        self.delta = source.stream(to: parser).split { packet in
            
        }
        
        self.serializer.stream(to: _serializer.stream(on: worker)).output(to: sink)
        
        self.executor.drain { task, _ in
            try self.process(task: task)
        }.upstream?.request()
    }
    
    func parse(packet: Packet) throws {
        guard self.connectionState == .done else {
            if let packet = try self.handshake(for: packet, state: &self.connectionState) {
                self.serializer.next(packet)
            }
            
            self.delta.request()
            return
        }
        
        switch state {
        case .nothing:
            throw MySQLError(.unexpectedResponse)
        case .closed:
            throw MySQLError(.unexpectedResponse)
        case .textQuerySent(let results):
            results.next(packet)
        }
    }
    
    fileprivate func process(task: Task) throws {
        self.currentTask = task
        
        guard let packet = task.packet else {
            return
        }
        
        self.state = makeState(for: task)
        
        serializer.next(packet)
    }
    
    func close() {
        // Write `close`
        _ = send(.close)
        
        executor.close()
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
            stream.connect(to: parser)
            return .textQuerySent(stream)
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

enum Task {
    case close
    case textQuery(String, TranslatingStreamWrapper<RowParser>)
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
