import Async
import Bits
import NIO

final class MySQLPacketEncoder: MessageToByteEncoder {
    /// See `MessageToByteEncoder.OutboundIn`
    typealias OutboundIn = MySQLPacket

    /// Called once there is data to encode. The used `ByteBuffer` is allocated by `allocateOutBuffer`.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ByteToMessageDecoder` belongs to.
    ///     - data: The data to encode into a `ByteBuffer`.
    ///     - out: The `ByteBuffer` into which we want to encode.
    func encode(ctx: ChannelHandlerContext, data message: MySQLPacket, out: inout ByteBuffer) throws {
        VERBOSE("MySQLPacketEncoder.encode(ctx: \(ctx), data: \(message), out: \(out))")

        let writeOffset = out.writerIndex
        out.write(bytes: [0x00, 0x00, 0x00, 0x00]) // save room for length
        switch message {
        case .handshakeResponse41(let handshakeResponse):
            handshakeResponse.serialize(into: &out)
        default: fatalError()
        }
        let bytesWritten = out.writerIndex - writeOffset
        out.set(integer: Byte(bytesWritten & 0xFF), at: writeOffset)
        out.set(integer: Byte(bytesWritten >> 8 & 0xFF), at: writeOffset + 1)
        out.set(integer: Byte(bytesWritten >> 16 & 0xFF), at: writeOffset + 2)
        // sequence ID
        out.set(integer: Byte(1), at: writeOffset + 3)

        ctx.write(wrapOutboundOut(out), promise: nil)
    }
}

