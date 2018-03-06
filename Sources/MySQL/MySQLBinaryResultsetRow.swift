import Bits
import Foundation

/// A Binary Protocol Resultset Row is made up of the NULL bitmap containing as many bits as we have columns
/// in the resultset + 2 and the values for columns that are not NULL in the Binary Protocol Value format.
struct MySQLBinaryResultsetRow {
    /// The values for this row.
    var values: [Data?]

    /// Parses a `MySQLBinaryResultsetRow` from the `ByteBuffer`.
    init(bytes: inout ByteBuffer, columnCount: Int) throws {
        let header = try bytes.requireInteger(as: Byte.self, source: .capture())
        guard header == 0x00 else {
            throw MySQLError(identifier: "resultHeader", reason: "Invalid result header", source: .capture())
        }

        let nullBitmap = try bytes.requireBytes(length: (columnCount + 7 + 2) / 8, source: .capture())
        print("NULLBITMAP (recv) \(nullBitmap)")

        var values: [Data?] = []

        for i in 0..<columnCount {
            if false {
                // null case
            } else {
                let data = try bytes.requireLengthEncodedString(source: .capture())
                values.append(Data(data.utf8))
            }
        }
        self.values = values
    }
}
