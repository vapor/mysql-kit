import Bits
import Foundation

/// ProtocolText::ResultsetRow
///
/// A row with the data for each column.
/// - NULL is sent as 0xfb
/// - everything else is converted into a string and is sent as Protocol::LengthEncodedString.
struct MySQLResultSetRow {
    /// The result set's data.
    var value: Data?

    /// Parses a `MySQLResultSetRow` from the `ByteBuffer`.
    init(bytes: inout ByteBuffer) throws {
        guard let peek: Byte = bytes.peekInteger() else {
            throw MySQLError(identifier: "peekRow", reason: "Could not peek row length.", source: .capture())
        }

        switch peek {
        case 0xFB:
            value = nil
        default:
            value = try bytes.requireLengthEncodedData(source: .capture())
        }
    }
}
