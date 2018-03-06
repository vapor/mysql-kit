import Bits

/// 14.6.4 COM_QUERY
///
/// A COM_QUERY is used to send the server a text-based query that is executed immediately.
/// The server replies to a COM_QUERY packet with a COM_QUERY Response.
/// The length of the query-string is a taken from the packet length - 1.
///
/// https://dev.mysql.com/doc/internals/en/com-query.html
struct MySQLComQuery {
    /// query (string.EOF) -- query_text
    var query: String

    /// Serializes the `MySQLComQuery` into a buffer.
    func serialize(into buffer: inout ByteBuffer) {
        /// command_id (1) -- 0x03 COM_QUERY
        buffer.write(integer: Byte(0x03))
        /// eof-terminated
        buffer.write(string: query)
    }
}
