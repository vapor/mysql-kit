import Foundation

/// Represents row data for a single MySQL column.
public struct MySQLData {
    /// The value's data.
    var storage: MySQLDataStorage

    /// Internal init using raw `MySQLBinaryDataStorage`.
    internal init(storage: MySQLDataStorage) {
        self.storage = storage
    }

    /// Creates a new `MySQLData` from a `String`.
    public init(string: String?) {
        let binary = MySQLBinaryData(
            type: .MYSQL_TYPE_VARCHAR,
            isUnsigned: true,
            storage: string.flatMap { .string(.init($0.utf8)) }
        )
        self.storage = .binary(binary)
    }

    /// Creates a new `MySQLData` from `Data`.
    public init(data: Data?) {
        let binary = MySQLBinaryData(
            type: .MYSQL_TYPE_BLOB,
            isUnsigned: true,
            storage: data.flatMap { .string($0) }
        )
        self.storage = .binary(binary)
    }

    /// Creates a new `MySQLData` from `Data`.
    public init<I>(integer: I?) where I: FixedWidthInteger {
        let type: MySQLDataType
        switch I.bitWidth {
        case 8: type = .MYSQL_TYPE_TINY
        case 16: type = .MYSQL_TYPE_SHORT
        case 32: type = .MYSQL_TYPE_LONG
        case 64: type = .MYSQL_TYPE_LONGLONG
        default: fatalError("Unsupported bit-width: \(I.bitWidth)")
        }

        let storage: MySQLBinaryDataStorage?

        if let integer = integer {
            if I.isSigned {
                storage = .integer8(numericCast(integer))
            } else {
                storage = .uinteger8(numericCast(integer))
            }
        } else {
            storage = nil
        }

        let binary = MySQLBinaryData(
            type: type,
            isUnsigned: !I.isSigned,
            storage: storage
        )
        self.storage = .binary(binary)
    }

    /// This value's data type
    public var type: MySQLDataType {
        switch storage {
        case .text: return .MYSQL_TYPE_VARCHAR
        case .binary(let binary): return binary.type
        }
    }

    /// Returns `true` if this data is null.
    public var isNull: Bool {
        switch storage {
        case .text(let data): return data == nil
        case .binary(let binary): return binary.storage == nil
        }
    }

    /// Access the value as data.
    public func data() -> Data? {
        switch storage {
        case .text(let data): return data
        case .binary(let binary):
            guard let value = binary.storage else {
                return nil
            }
            switch value {
            case .string(let data): return data
            default: return nil
            }
        }
    }

    /// Access the value as a string.
    public func string(encoding: String.Encoding = .utf8) -> String? {
        switch storage {
        case .text(let data): return data.flatMap { String(data: $0, encoding: .utf8) }
        case .binary(let binary):
            guard let value = binary.storage else {
                return nil
            }
            switch value {
            case .string(let data): return String(data: data, encoding: .utf8)
            default: return nil // support more
            }
        }
    }

    /// Access the value as an int.
    public func integer<I>(_ type: I.Type) throws -> I? where I: FixedWidthInteger {
        switch storage {
        case .text(let data): return data.flatMap { String(data: $0, encoding: .ascii) }.flatMap { I.init($0) }
        case .binary(let binary):
            guard let value = binary.storage else {
                return nil
            }

            switch value {
            case .integer1(let uint8):
                guard uint8 >= I.min else {
                    throw MySQLError(identifier: "intMin", reason: "Value \(uint8) too small for \(I.self).", source: .capture())
                }

                guard uint8 <= I.max else {
                    throw MySQLError(identifier: "intMax", reason: "Value \(uint8) too big for \(I.self).", source: .capture())
                }

                return I(uint8)
            case .integer2(let uint16):
                guard uint16 >= I.min else {
                    throw MySQLError(identifier: "intMin", reason: "Value \(uint16) too small for \(I.self).", source: .capture())
                }

                guard uint16 <= I.max else {
                    throw MySQLError(identifier: "intMax", reason: "Value \(uint16) too big for \(I.self).", source: .capture())
                }

                return I(uint16)
            case .integer4(let uint32):
                guard uint32 >= I.min else {
                    throw MySQLError(identifier: "intMin", reason: "Value \(uint32) too small for \(I.self).", source: .capture())
                }

                guard uint32 <= I.max else {
                    throw MySQLError(identifier: "intMax", reason: "Value \(uint32) too big for \(I.self).", source: .capture())
                }

                return I(uint32)
            case .integer8(let uint64):
                guard uint64 >= I.min else {
                    throw MySQLError(identifier: "intMin", reason: "Value \(uint64) too small for \(I.self).", source: .capture())
                }

                guard uint64 <= I.max else {
                    throw MySQLError(identifier: "intMax", reason: "Value \(uint64) too big for \(I.self).", source: .capture())
                }

                return I(uint64)
            case .uinteger1(let uint8):
                guard uint8 >= I.min else {
                    throw MySQLError(identifier: "intMin", reason: "Value \(uint8) too small for \(I.self).", source: .capture())
                }

                guard uint8 <= I.max else {
                    throw MySQLError(identifier: "intMax", reason: "Value \(uint8) too big for \(I.self).", source: .capture())
                }

                return I(uint8)
            case .uinteger2(let uint16):
                guard uint16 >= I.min else {
                    throw MySQLError(identifier: "intMin", reason: "Value \(uint16) too small for \(I.self).", source: .capture())
                }

                guard uint16 <= I.max else {
                    throw MySQLError(identifier: "intMax", reason: "Value \(uint16) too big for \(I.self).", source: .capture())
                }

                return I(uint16)
            case .uinteger4(let uint32):
                guard uint32 >= I.min else {
                    throw MySQLError(identifier: "intMin", reason: "Value \(uint32) too small for \(I.self).", source: .capture())
                }

                guard uint32 <= I.max else {
                    throw MySQLError(identifier: "intMax", reason: "Value \(uint32) too big for \(I.self).", source: .capture())
                }

                return I(uint32)
            case .uinteger8(let uint64):
                guard uint64 >= I.min else {
                    throw MySQLError(identifier: "intMin", reason: "Value \(uint64) too small for \(I.self).", source: .capture())
                }

                guard uint64 <= I.max else {
                    throw MySQLError(identifier: "intMax", reason: "Value \(uint64) too big for \(I.self).", source: .capture())
                }

                return I(uint64)
            case .string(let data):
                switch binary.type {
                case .MYSQL_TYPE_VARCHAR, .MYSQL_TYPE_VAR_STRING, .MYSQL_TYPE_STRING: return String(data: data, encoding: .ascii).flatMap { I.init($0) }
                case .MYSQL_TYPE_BIT:
                    if data.count == 1 {
                        return I(data[0])
                    } else {
                        return nil
                    }
                default: return nil

                }
            default: return nil // support more
            }
        }
    }
}

enum MySQLDataStorage {
    case text(Data?)
    case binary(MySQLBinaryData)
}

extension MySQLData: CustomStringConvertible {
    /// See `CustomStringConvertible.description`
    public var description: String {
        switch storage {
        case .text(let data):
            if let data = data {
                return String(data: data, encoding: .utf8).flatMap { "string(\"\($0)\")" } ?? "<non utf8 text>"
            } else {
                return "<null>"
            }
        case .binary(let binary):
            if let data = binary.storage {
                switch data {
                case .string(let data):
                    switch binary.type {
                    case .MYSQL_TYPE_VARCHAR, .MYSQL_TYPE_VAR_STRING:
                        return String(data: data, encoding: .utf8).flatMap { "string(\"\($0)\")" } ?? "<non-utf8 string (\(data.count))>"
                    default: return "data(0x\(data.hexString))"
                    }
                default: return "\(data)"
                }
            } else {
                return "<null>"
            }
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

public enum MySQLDataFormat {
    case text
    case binary
}

/// Capable of converting to/from `MySQLData`.
public protocol MySQLDataConvertible {
    /// Convert to `MySQLData`.
    func convertToMySQLData(format: MySQLDataFormat) throws -> MySQLData

    /// Convert from `MySQLData`.
    static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Self
}

extension String: MySQLDataConvertible {
    /// See `MySQLDataConvertible.convertToMySQLData(format:)`
    public func convertToMySQLData(format: MySQLDataFormat) throws -> MySQLData {
        return MySQLData(string: self)
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> String {
        guard let string = mysqlData.string() else {
            throw MySQLError(identifier: "string", reason: "Cannot decode String from MySQLData: \(mysqlData).", source: .capture())
        }
        return string
    }
}

extension FixedWidthInteger {
    /// See `MySQLDataConvertible.convertToMySQLData(format:)`
    public func convertToMySQLData(format: MySQLDataFormat) throws -> MySQLData {
        return MySQLData(integer: self)
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Self {
        guard let int = try mysqlData.integer(Self.self) else {
            throw MySQLError(identifier: "int", reason: "Cannot decode Int from MySQLData: \(mysqlData).", source: .capture())
        }

        return int
    }
}

extension Int8: MySQLDataConvertible { }
extension Int16: MySQLDataConvertible { }
extension Int32: MySQLDataConvertible { }
extension Int64: MySQLDataConvertible { }
extension Int: MySQLDataConvertible { }
extension UInt8: MySQLDataConvertible { }
extension UInt16: MySQLDataConvertible { }
extension UInt32: MySQLDataConvertible { }
extension UInt64: MySQLDataConvertible { }
extension UInt: MySQLDataConvertible { }
