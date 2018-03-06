import Bits

/// Table 14.4 Column Types
public struct MySQLColumnType: Equatable {
    /// The raw byte.
    public let raw: Byte

    /// Creates a new `MySQLColumnType`.
    public init(raw: Byte) {
        self.raw = raw
    }

    /// Implemented by ProtocolBinary::MYSQL_TYPE_DECIMAL
    public static let MYSQL_TYPE_DECIMAL: MySQLColumnType = 0x00

    /// Implemented by ProtocolBinary::MYSQL_TYPE_TINY
    public static let MYSQL_TYPE_TINY: MySQLColumnType = 0x01

    /// Implemented by ProtocolBinary::MYSQL_TYPE_SHORT
    public static let MYSQL_TYPE_SHORT: MySQLColumnType = 0x02

    /// Implemented by ProtocolBinary::MYSQL_TYPE_LONG
    public static let MYSQL_TYPE_LONG: MySQLColumnType = 0x03

    /// Implemented by ProtocolBinary::MYSQL_TYPE_FLOAT
    public static let MYSQL_TYPE_FLOAT: MySQLColumnType = 0x04

    /// Implemented by ProtocolBinary::MYSQL_TYPE_DOUBLE
    public static let MYSQL_TYPE_DOUBLE: MySQLColumnType = 0x05

    /// Implemented by ProtocolBinary::MYSQL_TYPE_NULL
    public static let MYSQL_TYPE_NULL: MySQLColumnType = 0x06

    /// Implemented by ProtocolBinary::MYSQL_TYPE_TIMESTAMP
    public static let MYSQL_TYPE_TIMESTAMP: MySQLColumnType = 0x07

    /// Implemented by ProtocolBinary::MYSQL_TYPE_LONGLONG
    public static let MYSQL_TYPE_LONGLONG: MySQLColumnType = 0x08

    /// Implemented by ProtocolBinary::MYSQL_TYPE_INT24
    public static let MYSQL_TYPE_INT24: MySQLColumnType = 0x09

    /// Implemented by ProtocolBinary::MYSQL_TYPE_DATE
    public static let MYSQL_TYPE_DATE: MySQLColumnType = 0x0a

    /// Implemented by ProtocolBinary::MYSQL_TYPE_TIME
    public static let MYSQL_TYPE_TIME: MySQLColumnType = 0x0b

    /// Implemented by ProtocolBinary::MYSQL_TYPE_DATETIME
    public static let MYSQL_TYPE_DATETIME: MySQLColumnType = 0x0c

    /// Implemented by ProtocolBinary::MYSQL_TYPE_YEAR
    public static let MYSQL_TYPE_YEAR: MySQLColumnType = 0x0d

    /// see Protocol::MYSQL_TYPE_DATE
    public static let MYSQL_TYPE_NEWDATE: MySQLColumnType = 0x0e

    /// Implemented by ProtocolBinary::MYSQL_TYPE_VARCHAR
    public static let MYSQL_TYPE_VARCHAR: MySQLColumnType = 0x0f

    /// Implemented by ProtocolBinary::MYSQL_TYPE_BIT
    public static let MYSQL_TYPE_BIT: MySQLColumnType = 0x10

    /// see Protocol::MYSQL_TYPE_TIMESTAMP
    public static let MYSQL_TYPE_TIMESTAMP2: MySQLColumnType = 0x11

    /// see Protocol::MYSQL_TYPE_DATETIME
    public static let MYSQL_TYPE_DATETIME2: MySQLColumnType = 0x12

    /// see Protocol::MYSQL_TYPE_TIME
    public static let MYSQL_TYPE_TIME2: MySQLColumnType = 0x13

    /// Implemented by ProtocolBinary::MYSQL_TYPE_NEWDECIMAL
    public static let MYSQL_TYPE_NEWDECIMAL: MySQLColumnType = 0xf6

    /// Implemented by ProtocolBinary::MYSQL_TYPE_ENUM
    public static let MYSQL_TYPE_ENUM: MySQLColumnType = 0xf7

    /// Implemented by ProtocolBinary::MYSQL_TYPE_SET
    public static let MYSQL_TYPE_SET: MySQLColumnType = 0xf8

    /// Implemented by ProtocolBinary::MYSQL_TYPE_TINY_BLOB
    public static let MYSQL_TYPE_TINY_BLOB: MySQLColumnType = 0xf9

    /// Implemented by ProtocolBinary::MYSQL_TYPE_MEDIUM_BLOB
    public static let MYSQL_TYPE_MEDIUM_BLOB: MySQLColumnType = 0xfa

    /// Implemented by ProtocolBinary::MYSQL_TYPE_LONG_BLOB
    public static let MYSQL_TYPE_LONG_BLOB: MySQLColumnType = 0xfb

    /// Implemented by ProtocolBinary::MYSQL_TYPE_BLOB
    public static let MYSQL_TYPE_BLOB: MySQLColumnType = 0xfc

    /// Implemented by ProtocolBinary::MYSQL_TYPE_VAR_STRING
    public static let MYSQL_TYPE_VAR_STRING: MySQLColumnType = 0xfd

    public static let MYSQL_TYPE_GEOMETRY: MySQLColumnType = 0xff
}

extension MySQLColumnType: ExpressibleByIntegerLiteral {
    /// See `ExpressibleByIntegerLiteral.init(integerLiteral:)`
    public init(integerLiteral value: Byte) {
        self.raw = value
    }
}

extension MySQLColumnType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .MYSQL_TYPE_DECIMAL: return "MYSQL_TYPE_DECIMAL"
        case .MYSQL_TYPE_TINY: return "MYSQL_TYPE_TINY"
        case .MYSQL_TYPE_SHORT: return "MYSQL_TYPE_SHORT"
        case .MYSQL_TYPE_LONG: return "MYSQL_TYPE_LONG"
        case .MYSQL_TYPE_FLOAT: return "MYSQL_TYPE_FLOAT"
        case .MYSQL_TYPE_DOUBLE: return "MYSQL_TYPE_DOUBLE"
        case .MYSQL_TYPE_NULL: return "MYSQL_TYPE_NULL"
        case .MYSQL_TYPE_TIMESTAMP: return "MYSQL_TYPE_TIMESTAMP"
        case .MYSQL_TYPE_LONGLONG: return "MYSQL_TYPE_LONGLONG"
        case .MYSQL_TYPE_INT24: return "MYSQL_TYPE_INT24"
        case .MYSQL_TYPE_DATE: return "MYSQL_TYPE_DATE"
        case .MYSQL_TYPE_TIME: return "MYSQL_TYPE_TIME"
        case .MYSQL_TYPE_DATETIME: return "MYSQL_TYPE_DATETIME"
        case .MYSQL_TYPE_YEAR: return "MYSQL_TYPE_YEAR"
        case .MYSQL_TYPE_NEWDATE: return "MYSQL_TYPE_NEWDATE"
        case .MYSQL_TYPE_VARCHAR: return "MYSQL_TYPE_VARCHAR"
        case .MYSQL_TYPE_BIT: return "MYSQL_TYPE_BIT"
        case .MYSQL_TYPE_TIMESTAMP2: return "MYSQL_TYPE_TIMESTAMP2"
        case .MYSQL_TYPE_DATETIME2: return "MYSQL_TYPE_DATETIME2"
        case .MYSQL_TYPE_TIME2: return "MYSQL_TYPE_TIME2"
        case .MYSQL_TYPE_NEWDECIMAL: return "MYSQL_TYPE_NEWDECIMAL"
        case .MYSQL_TYPE_ENUM: return "MYSQL_TYPE_ENUM"
        case .MYSQL_TYPE_SET: return "MYSQL_TYPE_SET"
        case .MYSQL_TYPE_TINY_BLOB: return "MYSQL_TYPE_TINY_BLOB"
        case .MYSQL_TYPE_MEDIUM_BLOB: return "MYSQL_TYPE_MEDIUM_BLOB"
        case .MYSQL_TYPE_LONG_BLOB: return "MYSQL_TYPE_LONG_BLOB"
        case .MYSQL_TYPE_BLOB: return "MYSQL_TYPE_BLOB"
        case .MYSQL_TYPE_VAR_STRING: return "MYSQL_TYPE_VAR_STRING"
        case .MYSQL_TYPE_GEOMETRY: return "MYSQL_TYPE_GEOMETRY"
        default: return "unknown (\(self.raw))"
        }
    }
}
