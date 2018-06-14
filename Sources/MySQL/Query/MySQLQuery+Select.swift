extension MySQLQuery {
    public struct OrderBy {
        public var expression: Expression
        public var direction: Direction
        
        public init(expression: Expression, direction: Direction) {
            self.expression = expression
            self.direction = direction
        }
    }
    
    public struct Select {
        public enum Distinct {
            case distinct
            case all
        }
        
        public enum ResultColumn {
            /// `*` and `table.*`
            case all(String?)
            /// `md5(a) AS hash`
            case expression(Expression, alias: String?)
        }
        
        public struct WithClause {
            public struct CommonTableExpression {
                public var table: String
                public var columns: [ColumnName]
                public var select: Select
            }
            
            public var recursive: Bool
            public var expressions: [CommonTableExpression]
        }
        
        
        public var with: WithClause?
        public var distinct: Distinct?
        public var columns: [ResultColumn]
        public var tables: [TableOrSubquery]
        public var predicate: Expression?
        public var orderBy: [OrderBy]
        
        public init(
            with: WithClause? = nil,
            distinct: Distinct? = nil,
            columns: [ResultColumn] = [],
            tables: [TableOrSubquery] = [],
            predicate: Expression? = nil,
            orderBy: [OrderBy] = []
        ) {
            self.with = with
            self.distinct = distinct
            self.columns = columns
            self.tables = tables
            self.predicate = predicate
            self.orderBy = orderBy
        }
    }
}

extension MySQLSerializer {
    func serialize(_ select: MySQLQuery.Select, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        sql.append("SELECT")
        if let with = select.with {
            sql.append(serialize(with, &binds))
        }
        if let distinct = select.distinct {
            sql.append(serialize(distinct))
        }
        sql.append(select.columns.map { serialize($0, &binds) }.joined(separator: ", "))
        if !select.tables.isEmpty {
            sql.append("FROM")
            sql.append(select.tables.map { serialize($0, &binds) }.joined(separator: ", "))
        }
        if let predicate = select.predicate {
            sql.append("WHERE")
            sql.append(serialize(predicate, &binds))
        }
        if !select.orderBy.isEmpty {
            sql.append("ORDER BY")
            sql.append(select.orderBy.map { serialize($0, &binds) }.joined(separator: ", "))
        }
        return sql.joined(separator: " ")
    }
    
    func serialize(_ orderBy: MySQLQuery.OrderBy, _ binds: inout [MySQLData]) -> String {
        return serialize(orderBy.expression, &binds) + " " + serialize(orderBy.direction)
    }
    
    func serialize(_ distinct: MySQLQuery.Select.Distinct) -> String {
        switch distinct {
        case .all: return "ALL"
        case .distinct: return "DISTINCT"
        }
    }
    
    func serialize(_ distinct: MySQLQuery.Select.ResultColumn, _ binds: inout [MySQLData]) -> String {
        switch distinct {
        case .all(let table):
            if let table = table {
                return escapeString(table) + ".*"
            } else {
                return "*"
            }
        case .expression(let expr, let alias):
            if let alias = alias {
                return serialize(expr, &binds) + " AS " + escapeString(alias)
            } else {
                return serialize(expr, &binds)
            }
        }
    }
    
    func serialize(_ with: MySQLQuery.Select.WithClause, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        sql.append("WITH")
        if with.recursive {
            sql.append("RECURSIVE")
        }
        sql.append(with.expressions.map { serialize($0, &binds) }.joined(separator: ", "))
        return sql.joined(separator: " ")
    }
    
    func serialize(_ cte: MySQLQuery.Select.WithClause.CommonTableExpression, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        sql.append(escapeString(cte.table))
        sql.append(serialize(cte.columns))
        sql.append("AS")
        sql.append("(" + serialize(cte.select, &binds) + ")")
        return sql.joined(separator: " ")
    }
}
