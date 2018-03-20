import Async
import Bits
import NIO

final class MySQLPacketEncoder: MessageToByteEncoder {
    /// See `MessageToByteEncoder.OutboundIn`
    typealias OutboundIn = MySQLPacket

    /// Information about this connection.
    var session: MySQLConnectionSession

    /// Creates a new `MySQLPacketDecoder`
    init(session: MySQLConnectionSession) {
        self.session = session
    }

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
        case .handshakeResponse41(let handshakeResponse): handshakeResponse.serialize(into: &out)
        case .comQuery(let comQuery):
            session.resetSequenceID()
            comQuery.serialize(into: &out)
            session.connectionState = .text(.waiting)
        case .comStmtPrepare(let comPrepare):
            session.resetSequenceID()
            comPrepare.serialize(into: &out)
            session.connectionState = .statement(.waitingPrepare)
        case .comStmtExecute(let comExecute):
            session.resetSequenceID()
            try comExecute.serialize(into: &out)
            session.connectionState = .statement(.waitingExecute)
        default: throw MySQLError(identifier: "encode", reason: "Unsupported packet: \(message)", source: .capture())
        }
        let bytesWritten = out.writerIndex - writeOffset - 4
        out.set(integer: Byte(bytesWritten & 0xFF), at: writeOffset)
        out.set(integer: Byte(bytesWritten >> 8 & 0xFF), at: writeOffset + 1)
        out.set(integer: Byte(bytesWritten >> 16 & 0xFF), at: writeOffset + 2)
        // sequence ID
        out.set(integer: session.nextSequenceID, at: writeOffset + 3)
    }
}

