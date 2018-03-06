import Bits
import Foundation

/// A Binary Protocol Resultset Row is made up of the NULL bitmap containing as many bits as we have columns
/// in the resultset + 2 and the values for columns that are not NULL in the Binary Protocol Value format.
struct MySQLBinaryResultsetRow {
    /// The values for this row.
    var values: [MySQLBinaryValueData?]

    /// Parses a `MySQLBinaryResultsetRow` from the `ByteBuffer`.
    init(bytes: inout ByteBuffer, columns: [MySQLColumnDefinition41]) throws {
        let header = try bytes.requireInteger(as: Byte.self, source: .capture())
        guard header == 0x00 else {
            throw MySQLError(identifier: "resultHeader", reason: "Invalid result header", source: .capture())
        }

        let nullBitmap = try bytes.requireBytes(length: (columns.count + 7 + 2) / 8, source: .capture())
        var values: [MySQLBinaryValueData?] = []

        for column in columns {
            if false {
                // null case
            } else {
                switch column.columnType {
                case .MYSQL_TYPE_VARCHAR,
                     .MYSQL_TYPE_VAR_STRING,
                     .MYSQL_TYPE_ENUM,
                     .MYSQL_TYPE_SET,
                     .MYSQL_TYPE_LONG_BLOB,
                     .MYSQL_TYPE_MEDIUM_BLOB,
                     .MYSQL_TYPE_BLOB,
                     .MYSQL_TYPE_TINY_BLOB,
                     .MYSQL_TYPE_GEOMETRY,
                     .MYSQL_TYPE_BIT,
                     .MYSQL_TYPE_DECIMAL,
                     .MYSQL_TYPE_NEWDECIMAL:
                    let data = try bytes.requireLengthEncodedData(source: .capture())
                    values.append(.string(data))
                case .MYSQL_TYPE_LONGLONG:
                    let int8 = try bytes.requireInteger(endianness: .little, as: UInt64.self, source: .capture())
                    values.append(.integer8(int8))
                case .MYSQL_TYPE_LONG, .MYSQL_TYPE_INT24:
                    let int4 = try bytes.requireInteger(endianness: .little, as: UInt32.self, source: .capture())
                    values.append(.integer4(int4))
                case .MYSQL_TYPE_SHORT, .MYSQL_TYPE_YEAR:
                    let int2 = try bytes.requireInteger(endianness: .little, as: UInt16.self, source: .capture())
                    values.append(.integer2(int2))
                case .MYSQL_TYPE_TINY:
                    let int1 = try bytes.requireInteger(endianness: .little, as: UInt8.self, source: .capture())
                    values.append(.integer1(int1))
                default: fatalError("Unsupported type: \(column)")
                }
            }
        }

        self.values = values
    }
}
