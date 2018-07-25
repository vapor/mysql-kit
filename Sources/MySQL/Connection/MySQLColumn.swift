/// Represents a MySQL column.
public struct MySQLColumn: Hashable {
    /// See `Hashable.hashValue`
    public var hashValue: Int {
        return (table?.hashValue ?? 0) &+ name.hashValue
    }

    /// See `Equatable.==`
    public static func ==(lhs: MySQLColumn, rhs: MySQLColumn) -> Bool {
        return lhs.name == rhs.name && lhs.table == rhs.table
    }

    /// The table this column belongs to.
    public var table: String?

    /// The column's name.
    public var name: String

    /// Creates a new `MySQLColumn`.
    public init(table: String? = nil, name: String) {
        self.table = table
        self.name = name
    }
}

extension MySQLColumn: ExpressibleByStringLiteral {
    /// See `ExpressibleByStringLiteral`.
    public init(stringLiteral value: String) {
        self.init(name: value)
    }
}

extension MySQLColumn: CustomStringConvertible {
    /// See `CustomStringConvertible`.
    public var description: String {
        if let table = table {
            return "\(table)(\(name))"
        } else {
            return "\(name)"
        }
    }
}

extension MySQLColumnDefinition41 {
    /// Converts a `MySQLColumnDefinition41` to `MySQLColumn`
    func makeMySQLColumn() -> MySQLColumn {
        return .init(
            table: table == "" ? nil : table,
            name: name
        )
    }
}

extension Dictionary where Key == MySQLColumn {
    /// Accesses the _first_ value from this dictionary with a matching field name.
    public func firstValue(forColumn columnName: String, inTable table: String? = nil) -> Value? {
        if table != nil, let specific = self[MySQLColumn(table: table, name: columnName)] {
            // check for column with matching table name
            return specific
        } else if let unspecific = self[MySQLColumn(table: nil, name: columnName)] {
            // check for column without table name
            return unspecific
        } else if table == nil {
            // check for column with table name where we don't specify one
            for (col, row) in self {
                if col.name == columnName {
                    return row
                }
            }
        }
        return nil
    }

    /// Access a `Value` from this dictionary keyed by `MySQLColumn`s
    /// using a field (column) name and entity (table) name.
    public func value(forTable table: String, atColumn column: String) -> Value? {
        return self[MySQLColumn(table: table, name: column)]
    }
}
