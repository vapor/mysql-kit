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

        let header = try bytes.requireInteger(endianness: .little, as: Byte.self, source: .capture())
        switch header {
        case 0xFF: break
        default: throw MySQLError(identifier: "errPacketHeader", reason: "Invalid ERR packet header: \(header)", source: .capture())
        }

        errorCode = try bytes.requireInteger(endianness: .little, source: .capture())
        if capabilities.get(CLIENT_PROTOCOL_41) {
            sqlStateMarker = try bytes.requireString(length: 1, source: .capture())
            sqlState = try bytes.requireString(length: 5, source: .capture())
        }

        errorMessage = try bytes.requireString(length: length - (bytes.readerIndex - startIndex), source: .capture())
    }
}

extension MySQLErrorPacket {
    /// Convert this `MySQLErrorPacket` to a `MySQLError`
    func makeError(source: SourceLocation) -> MySQLError {
        return MySQLError(identifier: "server (\(errorCode))", reason: errorMessage, source: source)
    }
}
