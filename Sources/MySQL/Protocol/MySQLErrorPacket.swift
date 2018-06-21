import Bits
import Debugging

/// 14.1.3.2 ERR_Packet
///
/// This packet signals that an error occurred. It contains a SQL state value if CLIENT_PROTOCOL_41 is enabled.
///
/// https://dev.mysql.com/doc/internals/en/packet-ERR_Packet.html
struct MySQLErrorPacket {
    /// error_code    error-code
    var errorCode: UInt16

    /// string[1] sql_state_marker    # marker of the SQL State
    var sqlStateMarker: String?

    /// string[5] sql_state    SQL State
    var sqlState: String?

    /// string<EOF>    error_message    human readable error message
    var errorMessage: String

    /// Parses a `MySQLEOFPacket` from the `ByteBuffer`.
    init(bytes: inout ByteBuffer, capabilities: MySQLCapabilities, length: Int) throws {
        let startIndex = bytes.readerIndex

        let header = try bytes.requireInteger(endianness: .little, as: Byte.self)
        switch header {
        case 0xFF: break
        default: throw MySQLError(identifier: "errPacketHeader", reason: "Invalid ERR packet header: \(header)")
        }

        errorCode = try bytes.requireInteger(endianness: .little)
        if capabilities.contains(.CLIENT_PROTOCOL_41) {
            sqlStateMarker = try bytes.requireString(length: 1)
            sqlState = try bytes.requireString(length: 5)
        }

        errorMessage = try bytes.requireString(length: length - (bytes.readerIndex - startIndex))
    }
}

extension MySQLErrorPacket {
    /// Convert this `MySQLErrorPacket` to a `MySQLError`
    func makeError(
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) -> MySQLError {
        return MySQLError(identifier: "server (\(errorCode))", reason: errorMessage, file: file, function: function, line: line, column: column)
    }
}
