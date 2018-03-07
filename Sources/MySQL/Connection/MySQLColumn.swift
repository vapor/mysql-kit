/// Represents a MySQL column.
public struct MySQLColumn: Hashable {
    /// See `Hashable.hashValue`
    public var hashValue: Int {
        return ((table ?? "_") + "." + name).hashValue
    }

    /// See `Equatable.==`
    public static func ==(lhs: MySQLColumn, rhs: MySQLColumn) -> Bool {
        return lhs.name == rhs.name && lhs.table == rhs.table
    }

    /// The table this column belongs to.
    public var table: String?

    /// The column's name.
    public var name: String
}

extension MySQLColumn: CustomStringConvertible {
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
    public func firstValue(forColumn columnName: String) -> Value? {
        for (field, value) in self {
            if field.name == columnName {
                return value
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

