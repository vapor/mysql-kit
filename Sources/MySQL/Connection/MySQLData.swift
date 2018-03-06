import Foundation

/// Represents row data for a single MySQL column.
public struct MySQLData {
    /// This value's column type
    public var type: MySQLColumnType

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
