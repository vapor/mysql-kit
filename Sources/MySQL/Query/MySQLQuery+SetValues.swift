extension MySQLQuery {
    public struct SetValues {
        public struct ColumnGroup {
            public var columns: [ColumnName]
            public var value: Expression
            
            public init(columns: [ColumnName], value: Expression) {
                self.columns = columns
                self.value = value
            }
        }
        
        public var columns: [ColumnGroup]
        public var predicate: Expression?
        
        public init(columns: [ColumnGroup], predicate: Expression? = nil) {
            self.columns = columns
            self.predicate = predicate
        }
    }
}

extension MySQLSerializer {
    func serialize(_ update: MySQLQuery.SetValues, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        sql.append(update.columns.map { serialize($0, &binds) }.joined(separator: ", "))
        if let predicate = update.predicate {
            sql.append("WHERE")
            sql.append(serialize(predicate, &binds))
        }
        return sql.joined(separator: " ")
    }
    
    func serialize(_ update: MySQLQuery.SetValues.ColumnGroup, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        switch update.columns.count {
        case 1: sql.append(serialize(update.columns[0]))
        default: sql.append(serialize(update.columns))
        }
        sql.append("=")
        sql.append(serialize(update.value, &binds))
        return sql.joined(separator: " ")
    }
}
