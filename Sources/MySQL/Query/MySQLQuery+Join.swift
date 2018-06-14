extension MySQLQuery {
    public struct JoinClause {
        public struct Join {
            public enum Operator {
                case inner
                case outer
                case cross
                
            }
            
            public enum Constraint {
                case condition(Expression)
                case using([ColumnName])
            }
            
            public var natural: Bool
            public var op: Operator?
            public var table: TableOrSubquery
            public var constraint: Constraint?
            
            public init(natural: Bool = false, _ op: Operator? = nil, table: TableOrSubquery, constraint: Constraint? = nil) {
                self.natural = natural
                self.op = op
                self.table = table
                self.constraint = constraint
            }
        }
        public var table: TableOrSubquery
        public var joins: [Join]
        
        public init(table: TableOrSubquery, joins: [Join] = []) {
            self.table = table
            self.joins = joins
        }
    }
}

extension MySQLSerializer {
    func serialize(_ join: MySQLQuery.JoinClause, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        sql.append(serialize(join.table, &binds))
        sql += join.joins.map { serialize($0, &binds) }
        return sql.joined(separator: " ")
    }
    
    func serialize(_ join: MySQLQuery.JoinClause.Join, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        if join.natural {
            sql.append("NATURAL")
        }
        if let op = join.op {
            sql.append(serialize(op))
            sql.append("JOIN")
        }
        sql.append(serialize(join.table, &binds))
        if let constraint = join.constraint {
            sql.append(serialize(constraint, &binds))
        }
        return sql.joined(separator: " ")
        
    }
    
    func serialize(_ constraint: MySQLQuery.JoinClause.Join.Constraint, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        switch constraint {
        case .condition(let expr):
            sql.append("ON")
            sql.append(serialize(expr, &binds))
        case .using(let columns):
            sql.append("USING")
            sql.append(serialize(columns))
        }
        return sql.joined(separator: " ")
    }
    
    func serialize(_ op: MySQLQuery.JoinClause.Join.Operator) -> String {
        switch op {
        case .outer: return "LEFT OUTER"
        case .inner: return "INNER"
        case .cross: return "CROSS"
        }
    }
}
