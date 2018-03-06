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
        case .waiting: return try decodeHandshake(ctx:ctx, buffer: &buffer)
        case .complete(let capabilities):
            switch session.connectionState {
            case .none: return try decodeOK(ctx: ctx, buffer: &buffer, capabilities: capabilities)
            case .text(let textState): return try decodeTextProtocol(ctx: ctx, buffer: &buffer, textState: textState)
            case .statement(let statementState): return try decodeStatementProtocol(ctx: ctx, buffer: &buffer, statementState: statementState, capabilities: capabilities)
            }
        }
    }

    // Decode the server greeting.
    func decodeHandshake(ctx: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        let packet: MySQLPacket
        let length = try buffer.requireInteger(endianness: .little, as: Int32.self, source: .capture())
        assert(length > 0)
        let handshake = try MySQLHandshakeV10(bytes: &buffer)
        packet = .handshakev10(handshake)
        session.handshakeState = .complete(handshake.capabilities)
        session.incrementSequenceID()
        ctx.fireChannelRead(wrapInboundOut(packet))
        return .continue
    }

    /// Decode's an OK, ERR, or EOF packet
    func decodeOK(ctx: ChannelHandlerContext, buffer: inout ByteBuffer, capabilities: MySQLCapabilities) throws -> DecodingState {
        print("DECODE OK")
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
            throw MySQLError(identifier: "basal", reason: "Unexpected message format during basal state", source: .capture())
        }
        return .continue
    }

    /// Text Protocol (Simple Query)
    func decodeTextProtocol(ctx: ChannelHandlerContext, buffer: inout ByteBuffer, textState: MySQLTextProtocolState) throws -> DecodingState {
        switch textState {
        case .waiting:
            guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                return .continue
            }
            let columnCount = try buffer.requireLengthEncodedInteger(source: .capture())
            let count = Int(columnCount)
            session.connectionState = .text(.columns(columnCount: count, remaining: count))
        case .columns(let columnCount, var remaining):
            guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                return .continue
            }
            let column = try MySQLColumnDefinition41(bytes: &buffer)
            session.incrementSequenceID()
            ctx.fireChannelRead(wrapInboundOut(.columnDefinition41(column)))
            remaining -= 1
            if remaining == 0 {
                session.connectionState = .text(.rows(columnCount: columnCount, remaining: columnCount))
            } else {
                session.connectionState = .text(.columns(columnCount: columnCount, remaining: remaining))
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
                    session.connectionState = .text(.rows(columnCount: columnCount, remaining: columnCount))
                }
            } else {
                session.connectionState = .text(.rows(columnCount: columnCount, remaining: remaining))
            }
        }
        return .continue
    }



    /// Statement Protocol (Prepared Query)
    func decodeStatementProtocol(ctx: ChannelHandlerContext, buffer: inout ByteBuffer, statementState: MySQLStatementProtocolState, capabilities: MySQLCapabilities) throws -> DecodingState {
        switch statementState {
        case .waitingPrepare:
            guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                return .continue
            }
            let ok = try MySQLComStmtPrepareOK(bytes: &buffer)
            session.incrementSequenceID()
            ctx.fireChannelRead(wrapInboundOut(.comStmtPrepareOK(ok)))
            if ok.numParams > 0 {
                session.connectionState = .statement(.params(ok: ok, remaining: numericCast(ok.numParams)))
            } else if ok.numColumns > 0 {
                session.connectionState = .statement(.columns(remaining: numericCast(ok.numColumns)))
            } else {
                session.connectionState = .statement(.columnsDone)
            }
        case .params(let ok, var remaining):
            guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                return .continue
            }

            let column = try MySQLColumnDefinition41(bytes: &buffer)
            session.incrementSequenceID()
            ctx.fireChannelRead(wrapInboundOut(.columnDefinition41(column)))

            remaining -= 1
            if remaining == 0 {
                session.connectionState = .statement(.paramsDone(ok: ok))
            } else {
                session.connectionState = .statement(.params(ok: ok, remaining: remaining))
            }
        case .paramsDone(let ok):
            if ok.numColumns > 0 {
                session.connectionState = .statement(.columns(remaining: numericCast(ok.numColumns)))
            } else {
                session.connectionState = .statement(.columnsDone)
            }

            if !capabilities.get(CLIENT_DEPRECATE_EOF) {
                return try decodeOK(ctx: ctx, buffer: &buffer, capabilities: capabilities)
            }
        case .columns(var remaining):
            guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                return .continue
            }

            let column = try MySQLColumnDefinition41(bytes: &buffer)
            session.incrementSequenceID()
            ctx.fireChannelRead(wrapInboundOut(.columnDefinition41(column)))

            remaining -= 1
            if remaining == 0 {
                session.connectionState = .statement(.columnsDone)
            } else {
                session.connectionState = .statement(.columns(remaining: remaining))
            }
        case .columnsDone:
            if !capabilities.get(CLIENT_DEPRECATE_EOF) {
                return try decodeOK(ctx: ctx, buffer: &buffer, capabilities: capabilities)
            }
        case .waitingExecute:
            guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                return .continue
            }
            let columnCount = try buffer.requireLengthEncodedInteger(source: .capture())
            let count = Int(columnCount)
            session.connectionState = .statement(.rowColumns(columns: [], remaining: count))
        case .rowColumns(var columns, var remaining):
            guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                return .continue
            }
            let column = try MySQLColumnDefinition41(bytes: &buffer)
            columns.append(column)
            session.incrementSequenceID()
            ctx.fireChannelRead(wrapInboundOut(.columnDefinition41(column)))
            remaining -= 1
            if remaining == 0 {
                session.connectionState = .statement(.rows(columns: columns))
            } else {
                session.connectionState = .statement(.rowColumns(columns: columns, remaining: remaining))
            }
        case .rows(let columns):
            if buffer.peekInteger(as: Byte.self, skipping: 4) == 0xFE {
                session.connectionState = .none
                print("ROWS DONE")
            } else {
                guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                    return .continue
                }

                let row = try MySQLBinaryResultsetRow(bytes: &buffer, columns: columns)
                ctx.fireChannelRead(wrapInboundOut(.binaryResultsetRow(row)))
            }
        }
        return .continue
    }
}
