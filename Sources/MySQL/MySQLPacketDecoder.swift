import Async
import Bits
import NIO

final class MySQLPacketDecoder: ByteToMessageDecoder {
    /// See `ByteToMessageDecoder.InboundOut`
    public typealias InboundOut = MySQLPacket

    /// The cumulationBuffer which will be used to buffer any data.
    var cumulationBuffer: ByteBuffer?

    /// This packet decoder's state.
    var state: MySQLPacketDecoderState

    /// Creates a new `MySQLPacketDecoder`
    init() {
        self.state = .awaitingHandshake
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

        switch state {
        case .awaitingHandshake:
            let length = buffer.assertReadInteger(endianness: .little, as: Int32.self)
            assert(length > 0)
            let handshake = MySQLHandshakeV10(bytes: &buffer, source: .capture())
            packet = .handshakev10(handshake)
            self.state = .normal
        case .normal:
            let length = buffer.assertReadInteger(endianness: .little, as: Int32.self)
            assert(length > 0)
            print(buffer.debugDescription)
            fatalError()
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

enum MySQLPacketDecoderState {
    case awaitingHandshake
    case normal
}
