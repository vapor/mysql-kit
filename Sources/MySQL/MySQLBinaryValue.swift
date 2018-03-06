import Foundation

/// 14.7.3 Binary Protocol Value
///
/// Represents a MySQL binary value.
///
/// https://dev.mysql.com/doc/internals/en/binary-protocol-value.html
public struct MySQLBinaryValue {
    /// This value's column type
    var type: MySQLColumnType

    /// If `true`, this value is unsigned.
    var isUnsigned: Bool

    /// The value's optional data.
    var data: Data?
}
