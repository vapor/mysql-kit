import Async

final class MySQLStateMachine {
    enum StreamState {
        case nothing, closed
        case textQuerySent(TranslatingStreamWrapper<RowParser>)
    }
    
    typealias Input = Task
    typealias Output = Packet
    
    var state: StreamState
    var currentTask: Task
    
    var worker: Worker
    let handshake: Handshake
    let parser: ConnectingStream<Packet>
    let executor: PushStream<Task>
    let serializer: PushStream<Packet>
    
    init(
        handshake: Handshake,
        parser: ConnectingStream<Packet>,
        serializer: PushStream<Packet>,
        worker: Worker
    ) {
        self.state = .nothing
        self.handshake = handshake
        self.parser = parser
        self.currentTask = .none
        self.worker = worker
        self.serializer = serializer
        self.executor = PushStream<Task>()
        
        self.executor.drain { task, _ in
            try self.process(task: task)
        }.upstream?.request()
        
        self.parser.drain(onInput: parse).upstream?.request()
    }
    
    fileprivate func parse(packet: Packet, upstream: ConnectionContext) throws {
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
        case .textQuery(_, let listener):
            let stream = self.makeRowParser(binary: false)
            
            _ = stream.drain { row, upstream in
                listener.next(row)
            }.catch(onError: listener.error).finally {
                listener.close()
                self.completeTask()
            }
            
            listener.connect(to: stream)
            
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
