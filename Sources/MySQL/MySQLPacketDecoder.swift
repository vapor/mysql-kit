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
        print(buffer.debugDescription)

        switch session.state {
        case .awaitingHandshake:
            let packet: MySQLPacket
            let length = try buffer.requireInteger(endianness: .little, as: Int32.self, source: .capture())
            assert(length > 0)
            let handshake = try MySQLHandshakeV10(bytes: &buffer)
            packet = .handshakev10(handshake)
            session.state = .handshakeComplete(handshake.capabilities)
            session.incrementSequenceID()
            ctx.fireChannelRead(wrapInboundOut(packet))
        case .handshakeComplete(let capabilities):
            let length = try buffer.requirePacketLength(source: .capture())
            guard let next: Byte = buffer.peekInteger() else {
                throw MySQLError(identifier: "peekHeader", reason: "Could not peek at header type.", source: .capture())
            }
            if next == 0x00 && length >= 7 {
                // parse OK packet
                let packet: MySQLPacket
                let ok = try MySQLOKPacket(bytes: &buffer, capabilities: capabilities, length: numericCast(length))
                print(ok)
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
                // parse simple query packets
                let columnCount = try buffer.requireLengthEncodedInteger(source: .capture())
                for _ in 0..<columnCount {
                    let colLength = try buffer.requirePacketLength(source: .capture())
                    assert(colLength > 0)
                    let column = try MySQLColumnDefinition41(bytes: &buffer)
                    session.incrementSequenceID()
                    ctx.fireChannelRead(wrapInboundOut(.columnDefinition41(column)))
                }
                rowParsing: while true {
                    let rowLength = try buffer.requirePacketLength(source: .capture())
                    assert(rowLength > 0)
                    
                    // parse cols for each row
                    for _ in 0..<columnCount {
                        let result = try MySQLResultSetRow(bytes: &buffer)
                        ctx.fireChannelRead(wrapInboundOut(.resultSetRow(result)))
                        if buffer.peekInteger(as: Byte.self, skipping: 4) == 0xFE {
                            // EOF detected, break
                            break rowParsing
                        }
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
