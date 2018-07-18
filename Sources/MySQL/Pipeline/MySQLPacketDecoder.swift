import Async
import Bits
import NIO

final class MySQLPacketDecoder: ByteToMessageDecoder {
    /// See `ByteToMessageDecoder.InboundOut`
    public typealias InboundOut = MySQLPacket

    /// The cumulationBuffer which will be used to buffer any data.
    var cumulationBuffer: ByteBuffer?

    /// Information about this connection.
    var session: MySQLPacketState

    /// Creates a new `MySQLPacketDecoder`
    init(session: MySQLPacketState) {
        self.session = session
    }

    func channelInactive(ctx: ChannelHandlerContext) {
        cumulationBuffer = nil
        ctx.fireChannelInactive()
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
        // print("\(#function) \(session.handshakeState)")
        switch session.handshakeState {
        case .waiting: return try decodeHandshake(ctx: ctx, buffer: &buffer)
        case .complete(let capabilities):
            // check if we need to decode an EOF first
            switch session.eofState {
            case .waiting:
                if !capabilities.contains(.CLIENT_DEPRECATE_EOF) {
                    print("decode deprecated EOF")
                    return try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities, forwarding: false)
                }
            default: break
            }
            
            // decode normally
            switch session.connectionState {
            case .none:
                return try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities)
            case .text(let textState):
                return try decodeTextProtocol(ctx: ctx, buffer: &buffer, textState: textState, capabilities: capabilities)
            case .statement(let statementState):
                return try decodeStatementProtocol(ctx: ctx, buffer: &buffer, statementState: statementState, capabilities: capabilities)
            }
        }
    }

    // Decode the server greeting.
    func decodeHandshake(ctx: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        let packet: MySQLPacket
        let length = try buffer.requireInteger(endianness: .little, as: Int32.self)
        assert(length > 0)
        
        guard let next: Byte = buffer.peekInteger() else {
            throw MySQLError(identifier: "peekHandshake", reason: "Could not peek at handshake type.")
        }
        if next == 0xFF {
            // parse error message, ignoring capabilities since the server has not supplied
            // any information about that yet
            let err = try MySQLErrorPacket(bytes: &buffer, capabilities: .init(), length: numericCast(length))
            packet = .err(err)
        } else {
            let handshake = try MySQLPacket.HandshakeV10(bytes: &buffer)
            packet = .handshakev10(handshake)
            session.handshakeState = .complete(handshake.capabilities)
            session.incrementSequenceID()
        }
        ctx.fireChannelRead(wrapInboundOut(packet))
        return .continue
    }

    /// Decode's an OK, ERR, or EOF packet
    func decodeBasicPacket(ctx: ChannelHandlerContext, buffer: inout ByteBuffer, capabilities: MySQLCapabilities, forwarding: Bool = true) throws -> DecodingState {
        guard let length = try buffer.checkPacketLength() else {
            return .needMoreData
        }
        guard let next: Byte = buffer.peekInteger() else {
            throw MySQLError(identifier: "peekHeader", reason: "Could not peek at header type.")
        }

        let packet: MySQLPacket
        if next == 0x00 && length >= 7 {
            // parse OK packet
            let ok = try MySQLPacket.OK(bytes: &buffer, capabilities: capabilities, length: numericCast(length))
            packet = .ok(ok)
        } else if next == 0xFE && length < 9 {
            if capabilities.contains(.CLIENT_DEPRECATE_EOF) {
                // parse EOF packet
                let eof = try MySQLPacket.OK(bytes: &buffer, capabilities: capabilities, length: numericCast(length))
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
        } else if next == 0x01, let second = buffer.peekInteger(skipping: 1, as: Byte.self) {
            // caching_sha2_password specific stuff
            switch second {
            case 0x03:
                // auth complete
                buffer.moveReaderIndex(forwardBy: 2)
                // decode the OK packet
                return try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities)
            case 0x04:
                // more data needed to complete auth
                buffer.moveReaderIndex(forwardBy: 2)
                packet = .fullAuthenticationRequest
            default:
                throw MySQLError(identifier: "basicPacket", reason: "Unrecognized basic packet.")
            }
        } else {
            throw MySQLError(identifier: "basicPacket", reason: "Unrecognized basic packet.")
        }

        session.incrementSequenceID()
        if forwarding {
            ctx.fireChannelRead(wrapInboundOut(packet))
        } else {
            session.eofState = .none
        }

        return .continue
    }

    /// Text Protocol (Simple Query)
    func decodeTextProtocol(
        ctx: ChannelHandlerContext,
        buffer: inout ByteBuffer,
        textState: MySQLTextProtocolState,
        capabilities: MySQLCapabilities
    ) throws -> DecodingState {
        // VERBOSE
        // print(textState)
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

            guard let _ = try buffer.checkPacketLength() else {
                return .needMoreData
            }
            let columnCount = try buffer.requireLengthEncodedInteger()
            let count = Int(columnCount)
            assert(count != 0, "should be parsed as an OK packet")
            session.connectionState = .text(.columns(columnCount: count, remaining: count))
        case .columns(let columnCount, var remaining):
            guard let _ = try buffer.checkPacketLength() else {
                return .needMoreData
            }
            let column = try MySQLColumnDefinition41(bytes: &buffer)
            session.incrementSequenceID()
            remaining -= 1
            if remaining == 0 {
                session.connectionState = .text(.rows(columnCount: columnCount, remaining: columnCount))
                session.eofState = .waiting
            } else {
                session.connectionState = .text(.columns(columnCount: columnCount, remaining: remaining))
            }
            ctx.fireChannelRead(wrapInboundOut(.columnDefinition41(column)))
        case .rows(let columnCount, var remaining):
            // check for EOF
            let peek = buffer.peekInteger(as: Byte.self, skipping: 4)
            switch peek {
            case 0xFE:
                session.connectionState = .none
                return try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities)
            default: break
            }
            
            if columnCount == remaining {
                // we are on a new set of results, check packet length again
                guard let _ = try buffer.checkPacketLength() else {
                    return .needMoreData
                }
            }

            let result = try MySQLResultSetRow(bytes: &buffer)
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
            ctx.fireChannelRead(wrapInboundOut(.resultSetRow(result)))
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

            guard let _ = try buffer.checkPacketLength() else {
                return .needMoreData
            }
            let ok = try MySQLComStmtPrepareOK(bytes: &buffer)
            session.incrementSequenceID()
            if ok.numParams > 0 {
                session.connectionState = .statement(.params(ok: ok, remaining: numericCast(ok.numParams)))
            } else if ok.numColumns > 0 {
                session.connectionState = .statement(.columns(remaining: numericCast(ok.numColumns)))
            } else {
                session.connectionState = .statement(.columnsDone(lastColumn: nil))
            }
            ctx.fireChannelRead(wrapInboundOut(.comStmtPrepareOK(ok)))
        case .params(let ok, var remaining):
            guard let _ = try buffer.checkPacketLength() else {
                return .needMoreData
            }

            let column = try MySQLColumnDefinition41(bytes: &buffer)
            session.incrementSequenceID()
            remaining -= 1
            if remaining == 0 {
                if !capabilities.contains(.CLIENT_DEPRECATE_EOF) {
                    session.connectionState = .statement(.paramsDone(ok: ok, lastColumn: column))
                } else {
                    // no eof, we can fire off column now
                    session.connectionState = .statement(.paramsDone(ok: ok, lastColumn: nil))
                    ctx.fireChannelRead(wrapInboundOut(.columnDefinition41(column)))
                }
            } else {
                session.connectionState = .statement(.params(ok: ok, remaining: remaining))
                ctx.fireChannelRead(wrapInboundOut(.columnDefinition41(column)))
            }
        case .paramsDone(let ok, let lastColumn):
            if !capabilities.contains(.CLIENT_DEPRECATE_EOF) {
                let res = try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities, forwarding: false)
                switch res {
                case .needMoreData:
                    return .needMoreData
                default: break
                }
            }

            if ok.numColumns > 0 {
                session.connectionState = .statement(.columns(remaining: numericCast(ok.numColumns)))
            } else {
                session.connectionState = .statement(.columnsDone(lastColumn: nil))
            }
            
            if let column = lastColumn {
                ctx.fireChannelRead(wrapInboundOut(.columnDefinition41(column)))
            }
        case .columns(var remaining):
            guard let _ = try buffer.checkPacketLength() else {
                return .needMoreData
            }

            let column = try MySQLColumnDefinition41(bytes: &buffer)
            session.incrementSequenceID()

            remaining -= 1
            if remaining == 0 {
                if !capabilities.contains(.CLIENT_DEPRECATE_EOF) {
                    // If EOF is not deprecated, don't proceed until full EOF is read
                    let res = try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities, forwarding: false)
                    switch res {
                    case .needMoreData:
                        // Defer firing the read event until the EOF is read
                        session.connectionState = .statement(.columnsDone(lastColumn: column))
                        return .needMoreData
                    default: break
                    }
                }
            } else {
                session.connectionState = .statement(.columns(remaining: remaining))
            }
            ctx.fireChannelRead(wrapInboundOut(.columnDefinition41(column)))
        case .columnsDone(let lastCol):
            guard let lastCol = lastCol else {
                // No pending column means there's no pending EOF to read
                break
            }
            if !capabilities.contains(.CLIENT_DEPRECATE_EOF) {
                // If EOF is not deprecated, don't proceed until full EOF is read
                let res = try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities, forwarding: false)
                switch res {
                case .needMoreData:
                    return .needMoreData
                default: break
                }
            }
            ctx.fireChannelRead(wrapInboundOut(.columnDefinition41(lastCol)))
        case .waitingExecute:
            // check for error or OK packet
            let peek = buffer.peekInteger(as: Byte.self, skipping: 4)
            switch peek {
            case 0xFF, 0x00:
                session.connectionState = .none
                return try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities)
            default: break
            }
            
            guard let _ = try buffer.checkPacketLength() else {
                return .needMoreData
            }
            let columnCount = try buffer.requireLengthEncodedInteger()
            let count = Int(columnCount)
            session.connectionState = .statement(.rowColumns(columns: [], remaining: count))
        case .rowColumns(var columns, var remaining):
            guard let _ = try buffer.checkPacketLength() else {
                return .needMoreData
            }
            let column = try MySQLColumnDefinition41(bytes: &buffer)
            columns.append(column)
            session.incrementSequenceID()
            remaining -= 1
            if remaining == 0 {
                session.connectionState = .statement(.rowColumnsDone(columns: columns))
            } else {
                session.connectionState = .statement(.rowColumns(columns: columns, remaining: remaining))
            }
            ctx.fireChannelRead(wrapInboundOut(.columnDefinition41(column)))
        case .rowColumnsDone(let columns):
            if !capabilities.contains(.CLIENT_DEPRECATE_EOF) {
                let result = try decodeBasicPacket(ctx: ctx, buffer: &buffer, capabilities: capabilities, forwarding: false)
                session.connectionState = .statement(.rows(columns: columns))
                return result
            }
            session.connectionState = .statement(.rows(columns: columns))
        case .rows(let columns):
            if buffer.peekInteger(as: Byte.self, skipping: 4) == 0xFE {
                session.connectionState = .none
            } else {
                guard let _ = try buffer.checkPacketLength() else {
                    return .needMoreData
                }

                let row = try MySQLBinaryResultsetRow(bytes: &buffer, columns: columns)
                ctx.fireChannelRead(wrapInboundOut(.binaryResultsetRow(row)))
            }
        }

        return .continue
    }
}
