import Foundation

/// 14.7.3 Binary Protocol Value
///
/// Represents a MySQL binary value.
///
/// https://dev.mysql.com/doc/internals/en/binary-protocol-value.html
public struct MySQLBinaryValue {
    /// This value's column type
    public var type: MySQLColumnType

    /// If `true`, this value is unsigned.
    public var isUnsigned: Bool

    /// The value's optional data.
    public var data: MySQLBinaryValueData?
}

/// 14.7.3 Binary Protocol Value
///
/// https://dev.mysql.com/doc/internals/en/binary-protocol-value.html
public enum MySQLBinaryValueData {
    /// ProtocolBinary::MYSQL_TYPE_STRING, ProtocolBinary::MYSQL_TYPE_VARCHAR, ProtocolBinary::MYSQL_TYPE_VAR_STRING, ProtocolBinary::MYSQL_TYPE_ENUM, ProtocolBinary::MYSQL_TYPE_SET, ProtocolBinary::MYSQL_TYPE_LONG_BLOB, ProtocolBinary::MYSQL_TYPE_MEDIUM_BLOB, ProtocolBinary::MYSQL_TYPE_BLOB, ProtocolBinary::MYSQL_TYPE_TINY_BLOB, ProtocolBinary::MYSQL_TYPE_GEOMETRY, ProtocolBinary::MYSQL_TYPE_BIT, ProtocolBinary::MYSQL_TYPE_DECIMAL, ProtocolBinary::MYSQL_TYPE_NEWDECIMAL:
    /// value (lenenc_str) -- string
    case string(Data)

    /// ProtocolBinary::MYSQL_TYPE_LONGLONG
    /// value (8) -- integer
    case integer8(UInt64)

    /// ProtocolBinary::MYSQL_TYPE_LONG, ProtocolBinary::MYSQL_TYPE_INT24:
    /// value (4) -- integer
    case integer4(UInt32)

    /// ProtocolBinary::MYSQL_TYPE_SHORT, ProtocolBinary::MYSQL_TYPE_YEAR:
    /// value (2) -- integer
    case integer2(UInt16)

    /// ProtocolBinary::MYSQL_TYPE_TINY:
    /// value (1) -- integer
    case integer1(UInt8)

    /// MYSQL_TYPE_DOUBLE stores a floating point in IEEE 754 double precision format
    /// first byte is the last byte of the significant as stored in C.
    /// value (string.fix_len) -- (len=8) double
    case float8(Double)

    /// MYSQL_TYPE_FLOAT stores a floating point in IEEE 754 single precision format
    /// value (string.fix_len) -- (len=4) float
    case float4(Float)
}
