extension MySQLQuery {
    public indirect enum TableOrSubquery {
        public enum TableIndex {
            case indexed(String)
            case notIndexed
        }
        
        case table(QualifiedTableName)
        case tableFunction(schemaName: String?, name: String, parameters: [Expression], alias: String?)
        case joinClause(JoinClause)
        case tables([TableOrSubquery])
        case subQuery(Select, alias: String?)
    }
}

extension MySQLQuery.TableOrSubquery: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .table(.init(stringLiteral: value))
    }
}

extension MySQLSerializer {
    func serialize(_ table: MySQLQuery.TableOrSubquery, _ binds: inout [MySQLData]) -> String {
        switch table {
        case .table(let table): return serialize(table)
        case .joinClause(let join): return serialize(join, &binds)
        default: return "\(table)"
        }
    }
}
