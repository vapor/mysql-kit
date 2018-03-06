/// Represents a MySQL column.
public struct MySQLColumn: Hashable {
    /// See `Hashable.hashValue`
    public var hashValue: Int {
        return name.hashValue
    }

    /// See `Equatable.==`
    public static func ==(lhs: MySQLColumn, rhs: MySQLColumn) -> Bool {
        if let ltable = lhs.table, let rtable = rhs.table {
            // if both have tables, check
            if ltable != rtable {
                return false
            }
        }
        return lhs.name == rhs.name
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
    public subscript(_ name: String) -> Value? {
        return self[MySQLColumn(table: nil, name: name)]
    }

    public subscript(table: String, name: String) -> Value? {
        return self[MySQLColumn(table: table, name: name)]
    }
}
