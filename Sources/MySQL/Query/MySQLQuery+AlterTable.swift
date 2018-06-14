extension MySQLQuery {
    public struct AlterTable {
        public enum Value {
            case rename(String)
            case addColumn(ColumnDefinition)
        }
        
        public var table: TableName
        public var value: Value
        
        public init(table: TableName, value: Value) {
            self.table = table
            self.value = value
        }
    }
}

extension MySQLSerializer {
    func serialize(_ alter: MySQLQuery.AlterTable, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        sql.append("ALTER TABLE")
        sql.append(serialize(alter.table))
        sql.append(serialize(alter.value, &binds))
        return sql.joined(separator: " ")
    }
    
    func serialize(_ value: MySQLQuery.AlterTable.Value, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        switch value {
        case .rename(let name):
            sql.append("RENAME TO")
            sql.append(escapeString(name))
        case .addColumn(let columnDefinition):
            sql.append("ADD")
            sql.append(serialize(columnDefinition, &binds))
        }
        return sql.joined(separator: " ")
    }
}
