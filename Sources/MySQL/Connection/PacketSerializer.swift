import Async
import Bits

/// Various states the parser stream can be in
enum ProtocolSerializerState {
    /// normal state
    case ready
    
    /// waiting for data from upstream
    case awaitingUpstream
}

final class MySQLPacketSerializer: ByteSerializerStream {
    /// See InputStream.Input
    typealias Input = Packet
    
    /// See OutputStream.RedisData
    typealias Output = ByteBuffer
    
    var state: ByteSerializerStreamState<MySQLPacketSerializer>
    
    func serialize(_ input: Packet) -> UnsafeBufferPointer<UInt8> {
        self.serializing = input
        return input.buffer
    }
    
    var serializing: Packet?
    
    fileprivate var _sequenceId: UInt8
    
    var sequenceId: UInt8 {
        get {
            defer { _sequenceId = _sequenceId &+ 1 }
            return _sequenceId
        }
        set {
            _sequenceId = newValue
        }
    }
    
    init() {
        state = .init()
        _sequenceId = 0
    }
    
    func nextCommandPhase() {
        self.sequenceId = 0
    }

    func send(_ packet: Packet, nextPhase: Bool = true) {
        if nextPhase {
            nextCommandPhase()
        }
        
        packet.sequenceId = self.sequenceId
        self.next(packet)
    }
}
