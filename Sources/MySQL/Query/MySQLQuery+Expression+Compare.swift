extension MySQLQuery.Expression {
    public struct Compare {
        public enum Operator {
            /// `LIKE`
            case like
            
            /// `GLOB`
            case glob
            
            /// `MATCH`
            case match
            
            /// `REGEXP`
            case regexp
        }
        
        public var left: MySQLQuery.Expression
        public var not: Bool
        public var op: Operator
        public var right: MySQLQuery.Expression
        public var escape: MySQLQuery.Expression?
        
        public init(
            _ left: MySQLQuery.Expression,
            not: Bool = false,
            _ op: Operator,
            _ right: MySQLQuery.Expression,
            escape: MySQLQuery.Expression? = nil
        ) {
            self.left = left
            self.not = not
            self.op = op
            self.right = right
            self.escape = escape
        }
    }
}

infix operator ~~
public func ~~(_ lhs: MySQLQuery.Expression, _ rhs: MySQLQuery.Expression) -> MySQLQuery.Expression {
    return .compare(.init(lhs, .like, rhs))
}

extension MySQLSerializer {
    func serialize(_ compare: MySQLQuery.Expression.Compare, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        sql.append(serialize(compare.left, &binds))
        if compare.not {
            sql.append("NOT")
        }
        sql.append(serialize(compare.op))
        sql.append(serialize(compare.right, &binds))
        if let escape = compare.escape {
            sql.append("ESCAPE")
            sql.append(serialize(escape, &binds))
        }
        return sql.joined(separator: " ")
    }
    func serialize(_ expr: MySQLQuery.Expression.Compare.Operator) -> String {
        switch expr {
        case .like: return "LIKE"
        case .glob: return "GLOB"
        case .match: return "MATCH"
        case .regexp: return "REGEXP"
        }
    }
}
