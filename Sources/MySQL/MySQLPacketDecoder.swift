import Async
import Bits
import NIO

final class MySQLPacketDecoder: ByteToMessageDecoder {
    /// See `ByteToMessageDecoder.InboundOut`
    public typealias InboundOut = MySQLPacket

    /// The cumulationBuffer which will be used to buffer any data.
    var cumulationBuffer: ByteBuffer?

    /// Information about this connection.
    var session: MySQLConnectionSession

    /// Creates a new `MySQLPacketDecoder`
    init(session: MySQLConnectionSession) {
        self.session = session
    }

    /// Decode from a `ByteBuffer`. This method will be called till either the input
    /// `ByteBuffer` has nothing to read left or `DecodingState.needMoreData` is returned.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ByteToMessageDecoder` belongs to.
    ///     - buffer: The `ByteBuffer` from which we decode.
    /// - returns: `DecodingState.continue` if we should continue calling this method or `DecodingState.needMoreData` if it should be called
    //             again once more data is present in the `ByteBuffer`.
    func decode(ctx: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        VERBOSE("MySQLPacketDecoder.decode(ctx: \(ctx), buffer: \(buffer)")

        let packet: MySQLPacket

        switch session.state {
        case .awaitingHandshake:
            let length = try buffer.requireInteger(endianness: .little, as: Int32.self, source: .capture())
            assert(length > 0)
            let handshake = try MySQLHandshakeV10(bytes: &buffer)
            packet = .handshakev10(handshake)
            session.state = .handshakeComplete(handshake.capabilities)
        case .handshakeComplete(let capabilities):
            buffer.set(integer: Byte(0), at: buffer.readerIndex + 3)
            let length = try buffer.requireInteger(endianness: .little, as: Int32.self, source: .capture())
            assert(length > 0)
            guard let next: Byte = buffer.peekInteger() else {
                throw MySQLError(identifier: "peekHeader", reason: "Could not peek at header type.", source: .capture())
            }
            if next == 0x00 && length >= 7 {
                // parse OK packet
                let ok = try MySQLOKPacket(bytes: &buffer, capabilities: capabilities, length: numericCast(length))
                print(ok)
                packet = .ok(ok)
            } else if next == 0xFE && length < 9 {
                // parse EOF packet
                fatalError()
            } else {
                // parse ?? packet
                fatalError()
            }
        }

        ctx.fireChannelRead(wrapInboundOut(packet))
        return .continue
    }

    /// Called once this `ByteToMessageDecoder` is removed from the `ChannelPipeline`.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ByteToMessageDecoder` belongs to.
    func decoderRemoved(ctx: ChannelHandlerContext) {
        VERBOSE("MySQLPacketDecoder.decoderRemoved(ctx: \(ctx))")
    }

    /// Called when this `ByteToMessageDecoder` is added to the `ChannelPipeline`.
    ///
    /// - parameters:
    ///     - ctx: The `ChannelHandlerContext` which this `ByteToMessageDecoder` belongs to.
    func decoderAdded(ctx: ChannelHandlerContext) {
        VERBOSE("MySQLPacketDecoder.decoderAdded(ctx: \(ctx))")
    }
}
