/// A type that can be represented by an appropriate `MySQLDataType` statically.
public protocol MySQLDataTypeStaticRepresentable {
    /// An appropriate `MySQLDataType` for this type.
    static var mysqlDataType: MySQLDataType { get }
}

extension UUID: MySQLDataTypeStaticRepresentable {
    /// See `MySQLDataTypeStaticRepresentable`.
    public static var mysqlDataType: MySQLDataType {
        return .varbinary(16)
    }
}

extension Date: MySQLDataTypeStaticRepresentable {
    /// See `MySQLDataTypeStaticRepresentable`.
    public static var mysqlDataType: MySQLDataType {
        return .datetime(6)
    }
}

extension String: MySQLDataTypeStaticRepresentable {
    /// See `MySQLDataTypeStaticRepresentable`.
    public static var mysqlDataType: MySQLDataType {
        return .varchar(255)
    }
}

extension FixedWidthInteger {
    /// See `MySQLDataTypeStaticRepresentable`.
    public static var mysqlDataType: MySQLDataType {
        switch bitWidth {
        case 8: return .tinyint(nil, unsigned: !isSigned, zerofill: false)
        case 16: return .smallint(nil, unsigned: !isSigned, zerofill: false)
        case 32: return .int(nil, unsigned: !isSigned, zerofill: false)
        case 64: return .bigint(nil, unsigned: !isSigned, zerofill: false)
        default: fatalError("Unsupported bit-width: \(bitWidth)")
        }
    }
}

extension Int8: MySQLDataTypeStaticRepresentable { }
extension Int16: MySQLDataTypeStaticRepresentable { }
extension Int32: MySQLDataTypeStaticRepresentable { }
extension Int64: MySQLDataTypeStaticRepresentable { }
extension Int: MySQLDataTypeStaticRepresentable { }
extension UInt8: MySQLDataTypeStaticRepresentable { }
extension UInt16: MySQLDataTypeStaticRepresentable { }
extension UInt32: MySQLDataTypeStaticRepresentable { }
extension UInt64: MySQLDataTypeStaticRepresentable { }
extension UInt: MySQLDataTypeStaticRepresentable { }

extension Bool: MySQLDataTypeStaticRepresentable {
    public static var mysqlDataType: MySQLDataType {
        /// See `MySQLDataTypeStaticRepresentable`.
        return .bool
    }
}

extension BinaryFloatingPoint {
    /// See `MySQLDataTypeStaticRepresentable`.
    public static var mysqlDataType: MySQLDataType {
        let bitWidth = exponentBitCount + significandBitCount + 1
        switch bitWidth {
        case 32: return .float(nil, unsigned: false, zerofill: false)
        case 64: return .double(nil, unsigned: false, zerofill: false)
        default: fatalError("Unsupported bit-width: \(bitWidth)")
        }
    }
}

extension Float: MySQLDataTypeStaticRepresentable { }
extension Double: MySQLDataTypeStaticRepresentable { }
