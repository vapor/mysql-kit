enum MySQLPacket {
    case handshakev10(MySQLHandshakeV10)
    case handshakeResponse41(MySQLHandshakeResponse41)
    case ok(MySQLOKPacket)
}
