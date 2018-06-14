enum MySQLPacket {
    case binaryResultsetRow(MySQLBinaryResultsetRow)
    case columnDefinition41(MySQLColumnDefinition41)
    case comQuery(MySQLComQuery)
    case comStmtExecute(MySQLComStmtExecute)
    case comStmtPrepare(MySQLComStmtPrepare)
    case comStmtPrepareOK(MySQLComStmtPrepareOK)
    case comStmtClose(ComStmtClose)
    case eof(MySQLEOFPacket)
    case err(MySQLErrorPacket)
    case fullAuthenticationRequest
    case handshakev10(HandshakeV10)
    case handshakeResponse41(HandshakeResponse41)
    case ok(OK)
    case plaintextPassword(String)
    case quit
    case resultSetRow(MySQLResultSetRow)
    case sslRequest(SSLRequest)
}

extension MySQLPacket {
    /// COM_STMT_CLOSE deallocates a prepared statement
    ///
    /// No response is sent back to the client.
    ///
    /// https://dev.mysql.com/doc/internals/en/com-stmt-close.html
    struct ComStmtClose {
        /// stmt-id
        var statementID: UInt32
        
        /// Serializes the `ComStmtClose` into a buffer.
        func serialize(into buffer: inout ByteBuffer) throws {
            buffer.write(integer: 0x19, as: UInt8.self)
            buffer.write(integer: statementID, endianness: .little)
        }
    }
}
