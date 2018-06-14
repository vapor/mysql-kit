extension MySQLQuery {
    public struct ColumnDefinition {
        public var name: ColumnName
        public var typeName: TypeName?
        public var constraints: [ColumnConstraint]
        
        public init(name: ColumnName, typeName: TypeName? = nil, constraints: [ColumnConstraint] = []) {
            self.name = name
            self.typeName = typeName
            self.constraints = constraints
        }
    }
}

extension MySQLSerializer {
    func serialize(_ columnDefinition: MySQLQuery.ColumnDefinition, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        sql.append(serialize(columnDefinition.name))
        if let typeName = columnDefinition.typeName {
            sql.append(serialize(typeName))
        }
        sql += columnDefinition.constraints.map { serialize($0, &binds) }
        return sql.joined(separator: " ")
    }
}
