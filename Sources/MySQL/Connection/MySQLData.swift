import Foundation

/// Represents row data for a single MySQL column.
public struct MySQLData {
    /// This value's column type
    public var type: MySQLColumnType

    /// The data's format.
    public var format: MySQLDataFormat

    /// The value's optional data.
    var value: MySQLBinaryValueData?

    /// Returns `true` if this data is null.
    public var isNull: Bool {
        return value == nil
    }

    /// Access the value as data.
    public var data: Data? {
        guard let value = value else {
            return nil
        }
        switch value {
        case .string(let data): return data
        default: return nil
        }
    }

    /// Access the value as a string.
    public var string: String? {
        guard let value = value else {
            return nil
        }
        switch value {
        case .string(let data): return String(data: data, encoding: .utf8)
        default: return nil // support more
        }
    }
}

public enum MySQLDataFormat {
    case binary
    case text
}

extension MySQLData: CustomStringConvertible {
    /// See `CustomStringConvertible.description`
    public var description: String {
        if let value = value {
            return "\(value)"
        } else {
            return "<null>"
        }
    }
}

extension MySQLData {
    /// Decodes a `MySQLDataConvertible` type from `MySQLData`.
    public func decode<T>(_ type: T.Type) throws -> T where T: MySQLDataConvertible {
        return try T.convertFromMySQLData(self)
    }
}

/// MARK: Convertible

/// Capable of converting to/from `MySQLData`.
public protocol MySQLDataConvertible {
    /// Convert to `MySQLData`.
    func convertToMySQLData() throws -> MySQLData

    /// Convert from `MySQLData`.
    static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Self
}

extension String: MySQLDataConvertible {
    /// See `MySQLDataConvertible.convertToMySQLData(format:)`
    public func convertToMySQLData() throws -> MySQLData {
        return MySQLData(type: .MYSQL_TYPE_VARCHAR, format: .binary, value: .string(.init(self.utf8)))
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> String {
        guard let string = mysqlData.string else {
            throw MySQLError(identifier: "string", reason: "Cannot decode String from MySQLData: \(mysqlData).", source: .capture())
        }
        return string
    }
}
