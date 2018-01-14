import Async

struct MySQLStateMachine: TranslatingStream {
    struct Task {
        var packet: Packet
        var state: MySQLStateMachine.StreamState
    }
    
    enum StreamState {
        case nothing, textQuerySent, closed
        
    }
    
    var state: StreamState
    let handshake: Handshake
    let parser: ConnectingStream<Packet>
    let executor: PushStream<Task>
    
    init(
        handshake: Handshake,
        parser: ConnectingStream<Packet>,
        serializer: PushStream<Packet>
    ) {
        self.state = .nothing
        self.handshake = handshake
        self.parser = parser
        self.executor = PushStream<Task>()
        
        self.executor.output(to: self)
        
        serializer.drain { packet, upstream in
            
        }
    }
    
    mutating func close() {
        // Write `close`
        send([
            0x01 // close identifier
        ], state: .closed)
        
        executor.close()
    }
    
    func send(_ packet: Packet, state: StreamState) {
        self.executor
    }
}

