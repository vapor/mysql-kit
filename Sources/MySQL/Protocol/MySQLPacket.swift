enum MySQLPacket {
    case binaryResultsetRow(MySQLBinaryResultsetRow)
    case columnDefinition41(MySQLColumnDefinition41)
    case comQuery(MySQLComQuery)
    case comStmtExecute(MySQLComStmtExecute)
    case comStmtPrepare(MySQLComStmtPrepare)
    case comStmtPrepareOK(MySQLComStmtPrepareOK)
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
