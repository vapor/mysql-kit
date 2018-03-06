enum MySQLPacket {
    case handshakev10(MySQLHandshakeV10)
    case handshakeResponse41(MySQLHandshakeResponse41)
    case ok(MySQLOKPacket)
    case comQuery(MySQLComQuery)
    case columnDefinition41(MySQLColumnDefinition41)
    case resultSetRow(MySQLResultSetRow)
    case eof(MySQLEOFPacket)
    case comStmtPrepare(MySQLComStmtPrepare)
    case comStmtPrepareOK(MySQLComStmtPrepareOK)
    case comStmtExecute(MySQLComStmtExecute)
    case binaryResultsetRow(MySQLBinaryResultsetRow)
    case err(MySQLErrorPacket)
}
