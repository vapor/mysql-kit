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
        switch session.handshakeState {
        case .waiting:

            /// MARK: Handshake

            let packet: MySQLPacket
            let length = try buffer.requireInteger(endianness: .little, as: Int32.self, source: .capture())
            assert(length > 0)
            let handshake = try MySQLHandshakeV10(bytes: &buffer)
            packet = .handshakev10(handshake)
            session.handshakeState = .complete(handshake.capabilities)
            session.incrementSequenceID()
            ctx.fireChannelRead(wrapInboundOut(packet))
        case .complete(let capabilities):
            switch session.connectionState {
            case .none:

                /// MARK: Base Connection State

                guard let length = try buffer.checkPacketLength(source: .capture()) else {
                    return .continue
                }
                guard let next: Byte = buffer.peekInteger() else {
                    throw MySQLError(identifier: "peekHeader", reason: "Could not peek at header type.", source: .capture())
                }
                if next == 0x00 && length >= 7 {
                    // parse OK packet
                    let packet: MySQLPacket
                    let ok = try MySQLOKPacket(bytes: &buffer, capabilities: capabilities, length: numericCast(length))
                    packet = .ok(ok)
                    session.incrementSequenceID()
                    ctx.fireChannelRead(wrapInboundOut(packet))
                } else if next == 0xFE && length < 9 {
                    if capabilities.get(CLIENT_DEPRECATE_EOF) {
                        // parse EOF packet
                        let packet: MySQLPacket
                        let eof = try MySQLOKPacket(bytes: &buffer, capabilities: capabilities, length: numericCast(length))
                        packet = .ok(eof)
                        session.incrementSequenceID()
                        ctx.fireChannelRead(wrapInboundOut(packet))
                    } else {
                        // parse EOF packet
                        let packet: MySQLPacket
                        let eof = try MySQLEOFPacket(bytes: &buffer, capabilities: capabilities)
                        packet = .eof(eof)
                        session.incrementSequenceID()
                        ctx.fireChannelRead(wrapInboundOut(packet))
                    }
                } else {
                    fatalError()
                }
            case .textProtocol(let simpleQueryState):

                /// MARK: Text Protocol (Simple Query)

                switch simpleQueryState {
                case .waiting:
                    guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                        return .continue
                    }
                    let columnCount = try buffer.requireLengthEncodedInteger(source: .capture())
                    let count = Int(columnCount)
                    session.connectionState = .textProtocol(.columns(columnCount: count, remaining: count))
                case .columns(let columnCount, var remaining):
                    guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                        return .continue
                    }
                    let column = try MySQLColumnDefinition41(bytes: &buffer)
                    session.incrementSequenceID()
                    ctx.fireChannelRead(wrapInboundOut(.columnDefinition41(column)))
                    remaining -= 1
                    if remaining == 0 {
                        session.connectionState = .textProtocol(.rows(columnCount: columnCount, remaining: columnCount))
                    } else {
                        session.connectionState = .textProtocol(.columns(columnCount: columnCount, remaining: remaining))
                    }
                case .rows(let columnCount, var remaining):
                    if columnCount == remaining {
                        // we are on a new set of results, check packet length again
                        guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                            return .continue
                        }
                    }

                    let result = try MySQLResultSetRow(bytes: &buffer)
                    ctx.fireChannelRead(wrapInboundOut(.resultSetRow(result)))
                    remaining -= 1
                    if remaining == 0 {
                        if buffer.peekInteger(as: Byte.self, skipping: 4) == 0xFE {
                            session.connectionState = .none
                        } else {
                            session.connectionState = .textProtocol(.rows(columnCount: columnCount, remaining: columnCount))
                        }
                    } else {
                        session.connectionState = .textProtocol(.rows(columnCount: columnCount, remaining: remaining))
                    }
                }
            }
        }

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
