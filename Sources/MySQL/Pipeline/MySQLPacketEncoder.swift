import Async
import Bits
import NIO

final class MySQLPacketEncoder: MessageToByteEncoder {
    /// See `MessageToByteEncoder.OutboundIn`
    typealias OutboundIn = MySQLPacket

    /// Information about this connection.
    var session: MySQLPacketState

    /// Creates a new `MySQLPacketDecoder`
    init(session: MySQLPacketState) {
        self.session = session
    }

    /// Called once there is data to encode. The used `ByteBuffer` is allocated by `allocateOutBuffer`.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ByteToMessageDecoder` belongs to.
    ///     - data: The data to encode into a `ByteBuffer`.
    ///     - out: The `ByteBuffer` into which we want to encode.
    func encode(ctx: ChannelHandlerContext, data message: MySQLPacket, out: inout ByteBuffer) throws {
        // VERBOSE
        // print("➡️ \(message)")
        // print("\(#function) \(session.handshakeState)")
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
        case .comStmtClose(let comClose):
            session.resetSequenceID()
            try comClose.serialize(into: &out)
        case .quit:
            session.resetSequenceID()
            out.write(integer: 1, as: UInt8.self)
        case .sslRequest(let sslRequest):
            sslRequest.serialize(into: &out)
        case .plaintextPassword(let string):
            out.write(string: string)
            out.write(integer: Byte(0))
        default: throw MySQLError(identifier: "encodePacket", reason: "Unexpected packet.")
        }
        let bytesWritten = out.writerIndex - writeOffset - 4
        out.set(integer: Byte(bytesWritten & 0xFF), at: writeOffset)
        out.set(integer: Byte(bytesWritten >> 8 & 0xFF), at: writeOffset + 1)
        out.set(integer: Byte(bytesWritten >> 16 & 0xFF), at: writeOffset + 2)
        // sequence ID
        out.set(integer: session.nextSequenceID, at: writeOffset + 3)
    }
}

