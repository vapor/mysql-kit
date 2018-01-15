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
    
    init() {
        self.state = .init()
    }
    
    func serialize(_ input: Packet, state: Bool?) throws -> ByteSerializerResult<MySQLPacketSerializer> {
        self.serializing = input
        return .complete(input.buffer)
    }
}
