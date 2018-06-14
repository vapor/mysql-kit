extension MySQLQuery {
    public struct TableConstraint {
        public struct UniqueOrPrimaryKey {
            public var columns: [IndexedColumn]
            public var conflictResolution: ConflictResolution?
            
            public init(columns: [IndexedColumn], conflictResolution: ConflictResolution? = nil) {
                self.columns = columns
                self.conflictResolution = conflictResolution
            }
        }
        
        public enum Value {
            case primaryKey(UniqueOrPrimaryKey)
            case unique(UniqueOrPrimaryKey)
            case check(Expression)
            case foreignKey(ForeignKey)
        }
        
        public var name: String?
        public var value: Value
        public init (name: String? = nil, _ value: Value) {
            self.name = name
            self.value = value
        }
    }
}

extension MySQLSerializer {
    func serialize(_ constraint: MySQLQuery.TableConstraint, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        if let name = constraint.name {
            sql.append("CONSTRAINT")
            sql.append(escapeString(name))
        }
        sql.append(serialize(constraint.value, &binds))
        return sql.joined(separator: " ")
    }
    
    func serialize(_ value: MySQLQuery.TableConstraint.Value, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        switch value {
        case .primaryKey(let primaryKey):
            sql.append("PRIMARY KEY")
            sql.append(
                "(" + primaryKey.columns.map { serialize($0, &binds) }.joined(separator: ", ") + ")"
            )
            if let conflictResolution = primaryKey.conflictResolution {
                sql.append("ON CONFLICT")
                sql.append(serialize(conflictResolution))
            }
        case .unique(let unique):
            sql.append("UNIQUE")
            sql.append(
                "(" + unique.columns.map { serialize($0, &binds) }.joined(separator: ", ") + ")"
            )
            if let conflictResolution = unique.conflictResolution {
                sql.append("ON CONFLICT")
                sql.append(serialize(conflictResolution))
            }
        case .check(let expr):
            sql.append("CHECK")
            sql.append("(" + serialize(expr, &binds) + ")")
        case .foreignKey(let foreignKey):
            sql.append(serialize(foreignKey))
        }
        return sql.joined(separator: " ")
    }
}
