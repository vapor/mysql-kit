extension MySQLQuery {
    public struct WithClause {
        public struct CommonTableExpression {
            public var table: String
            public var select: Select
        }
        
        public var recursive: Bool
        public var expressions: [CommonTableExpression]
    }
}

extension MySQLSerializer {
    func serialize(_ with: MySQLQuery.WithClause, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        sql.append("WITH")
        if with.recursive {
            sql.append("RECURSIVE")
        }
        sql.append(with.expressions.map { serialize($0, &binds) }.joined(separator: ", "))
        return sql.joined(separator: " ")
    }
    
    func serialize(_ cte: MySQLQuery.WithClause.CommonTableExpression, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        sql.append(escapeString(cte.table))
        sql.append("AS")
        sql.append("(" + serialize(cte.select, &binds) + ")")
        return sql.joined(separator: " ")
    }
}
