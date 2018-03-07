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
            case .none: return try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities)
            case .text(let textState): return try decodeTextProtocol(ctx: ctx, buffer: &buffer, textState: textState, capabilities: capabilities)
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
    func decodeBasicPacket(ctx: ChannelHandlerContext, buffer: inout ByteBuffer, capabilities: MySQLCapabilities) throws -> DecodingState {
        guard let length = try buffer.checkPacketLength(source: .capture()) else {
            return .needMoreData
        }
        guard let next: Byte = buffer.peekInteger() else {
            throw MySQLError(identifier: "peekHeader", reason: "Could not peek at header type.", source: .capture())
        }

        let packet: MySQLPacket
        if next == 0x00 && length >= 7 {
            // parse OK packet
            let ok = try MySQLOKPacket(bytes: &buffer, capabilities: capabilities, length: numericCast(length))
            packet = .ok(ok)
        } else if next == 0xFE && length < 9 {
            if capabilities.get(CLIENT_DEPRECATE_EOF) {
                // parse EOF packet
                let eof = try MySQLOKPacket(bytes: &buffer, capabilities: capabilities, length: numericCast(length))
                packet = .ok(eof)
            } else {
                // parse EOF packet
                let eof = try MySQLEOFPacket(bytes: &buffer, capabilities: capabilities)
                packet = .eof(eof)
            }
        } else if next == 0xFF {
            // parse error message
            let err = try MySQLErrorPacket(bytes: &buffer, capabilities: capabilities, length: numericCast(length))
            packet = .err(err)
        } else {
            throw MySQLError(identifier: "basicPacket", reason: "Unrecognized basic packet.", source: .capture())
        }

        session.incrementSequenceID()
        ctx.fireChannelRead(wrapInboundOut(packet))

        return .continue
    }

    /// Text Protocol (Simple Query)
    func decodeTextProtocol(
        ctx: ChannelHandlerContext,
        buffer: inout ByteBuffer,
        textState: MySQLTextProtocolState,
        capabilities: MySQLCapabilities
    ) throws -> DecodingState {
        switch textState {
        case .waiting:
            // check for error or OK packet
            let peek = buffer.peekInteger(as: Byte.self, skipping: 4)
            switch peek {
            case 0xFF, 0x00:
                session.connectionState = .none
                return try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities)
            default: break
            }

            guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                return .needMoreData
            }
            let columnCount = try buffer.requireLengthEncodedInteger(source: .capture())
            let count = Int(columnCount)
            assert(count != 0, "should be parsed as an OK packet")
            session.connectionState = .text(.columns(columnCount: count, remaining: count))
        case .columns(let columnCount, var remaining):
            guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                return .needMoreData
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
                    return .needMoreData
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
            // check for error packet
            let peek = buffer.peekInteger(as: Byte.self, skipping: 4)
            switch peek {
            case 0xFF:
                session.connectionState = .none
                return try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities)
            default: break
            }

            guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                return .needMoreData
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
                return .needMoreData
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
                return try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities)
            }
        case .columns(var remaining):
            guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                return .needMoreData
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
                return try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities)
            }
        case .waitingExecute:
            // check for error or OK packet
            let peek = buffer.peekInteger(as: Byte.self, skipping: 4)
            switch peek {
            case 0xFF, 0x00:
                session.connectionState = .none
                return try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities)
            default: break
            }
            
            guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                return .needMoreData
            }
            let columnCount = try buffer.requireLengthEncodedInteger(source: .capture())
            let count = Int(columnCount)
            session.connectionState = .statement(.rowColumns(columns: [], remaining: count))
        case .rowColumns(var columns, var remaining):
            guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                return .needMoreData
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
            } else {
                guard let _ = try buffer.checkPacketLength(source: .capture()) else {
                    return .needMoreData
                }

                let row = try MySQLBinaryResultsetRow(bytes: &buffer, columns: columns)
                ctx.fireChannelRead(wrapInboundOut(.binaryResultsetRow(row)))
            }
        }

        return .continue
    }
}
