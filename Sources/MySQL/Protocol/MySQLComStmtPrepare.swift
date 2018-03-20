import Bits

/// 14.7.4 COM_STMT_PREPARE
///
/// COM_STMT_PREPARE creates a prepared statement from the passed query string.
/// The server returns a COM_STMT_PREPARE Response which contains a statement-id which is used to identify the prepared statement.
///
/// https://dev.mysql.com/doc/internals/en/com-stmt-prepare.html#packet-COM_STMT_PREPARE
struct MySQLComStmtPrepare {
    /// query (string.EOF) -- the query to prepare
    var query: String

    /// Serializes the `MySQLComStmtPrepare` into a buffer.
    func serialize(into buffer: inout ByteBuffer) {
        /// command (1) -- [16] the COM_STMT_PREPARE command
        buffer.write(integer: Byte(0x16))
        /// eof-terminated
        buffer.write(string: query)
    }
}
