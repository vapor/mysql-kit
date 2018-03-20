import Bits

/// 14.1.3.3 EOF_Packet
///
/// If CLIENT_PROTOCOL_41 is enabled, the EOF packet contains a warning count and status flags.
///
/// In the MySQL client/server protocol, EOF and OK packets serve the same purpose, to mark the end of a query execution result.
/// Due to changes in MySQL 5.7 in the OK packet (such as session state tracking), and to avoid repeating the changes in the EOF packet, the EOF packet is deprecated as of MySQL 5.7.5.
struct MySQLEOFPacket {
    ///  int<2>    warnings    number of warnings
    var warningsCount: UInt16?

    /// int<2>    status_flags    Status Flags
    var statusFlags: MySQLStatusFlags

    /// Parses a `MySQLEOFPacket` from the `ByteBuffer`.
    init(bytes: inout ByteBuffer, capabilities: MySQLCapabilities) throws {
        let header = try bytes.requireInteger(endianness: .little, as: Byte.self, source: .capture())
        switch header {
        case 0xFE: break
        default: throw MySQLError(identifier: "eofPacketHeader", reason: "Invalid EOF packet header: \(header)", source: .capture())
        }

        if capabilities.get(CLIENT_PROTOCOL_41) {
            warningsCount = try bytes.requireInteger(endianness: .little, source: .capture())
            statusFlags = try .init(raw: bytes.requireInteger(endianness: .little, source: .capture()))
        } else {
            statusFlags = .init(raw: 0)
        }
    }
}
