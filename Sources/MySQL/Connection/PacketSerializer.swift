import Async
import Bits

final class MySQLPacketSerializer: ByteSerializer {
    var state: ByteSerializerState<MySQLPacketSerializer>
    
    /// See InputStream.Input
    typealias Input = Packet
    
    /// See OutputStream.RedisData
    typealias Output = ByteBuffer
    
    /// No state
    typealias SerializationState = Bool
    
    var serializing: Packet?
    
//    var state: ProtocolParserState
    
    var sequenceId: UInt8
    
    init() {
        self.state = .init()
        sequenceId = 0
    }
    
    func serialize(_ input: Packet, state: Bool?) throws -> ByteSerializerResult<MySQLPacketSerializer> {
        input.sequenceId = sequenceId
        self.serializing = input
        return .complete(input.buffer)
    }
}
