import Async

import Bits

final class MySQLStateMachine {
    let user: String
    let password: String?
    let database: String
    
    /// The inserted ID from the last successful query
    var lastInsertID: UInt64?
    
    /// Amount of affected rows in the last successful query
    var affectedRows: UInt64?
    
    var handshake: Handshake?
    /// We currently don't use sequenceId
    var sequenceId: UInt8
    private let ssl: MySQLSSLConfig?
    let connected = Promise<Void>()
    private let worker: Worker
    private let parser: TranslatingStreamWrapper<MySQLPacketParser>
    private let queue: QueueStream<Packet, Packet>
    private let serializer: MySQLPacketSerializer
    private var tasks: [AnyTask]
    
    init<O: OutputStream, I: InputStream>(
        source: O,
        sink: I,
        user: String,
        password: String?,
        database: String,
        ssl: MySQLSSLConfig?,
        worker: Worker
    ) where O.Output == ByteBuffer, I.Input == ByteBuffer {
        self.parser = MySQLPacketParser().stream(on: worker)
        self.ssl = ssl
        self.sequenceId = 0
        self.worker = worker
        self.serializer = MySQLPacketSerializer()
        self.queue = QueueStream<Packet, Packet>()
        self.user = user
        self.password = password
        self.database = database
        self.tasks = []
        
        self.connected.future.do {
            for task in self.tasks {
                self.execute(task.task)
            }
        }.catch { error in
            for task in self.tasks {
                _ = try? task.task.interrupted(by: error)
            }
        }.always {
            self.tasks = []
        }
        
        self.execute(StartHandshake(context: self))
        
        source
            .stream(to: parser)
            .stream(to: queue)
            .stream(to: serializer.stream(on: worker))
            .output(to: sink)
    }
    
    @discardableResult
    func execute(_ task: Task) -> Future<Void> {
        return self.queue.enqueue(task.packets, onInput: task.run)
    }
    
    func close(immediately: Bool = false) {
        self.execute(Close())
        self.queue.close()
    }
}

extension Task {
    fileprivate func run(using packet: Packet) throws -> Bool {
        do {
            return try self.update(with: packet)
        } catch {
            try self.interrupted(by: error)
            return true
        }
    }
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
