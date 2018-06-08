extension MySQLQuery {
    public struct ColumnConstraint {
        public static func primaryKey(autoIncrement: Bool = true) -> ColumnConstraint {
            return .init(.primaryKey(.init(autoIncrement: autoIncrement)))
        }
        
        public static var notNull: ColumnConstraint {
            return .init(.nullability(.init(allowNull: false)))
        }
        
        public static func `default`(_ expression: Expression) -> ColumnConstraint {
            return .init(.default(expression))
        }
        
        public static func foreignKey<Table, Value>(
            to keyPath: KeyPath<Table, Value>
        ) -> ColumnConstraint
            where Table: SQLiteTable
        {
            let fk = ForeignKeyReference.init(
                foreignTable: .init(name: Table.sqliteTableName),
                foreignColumns: [keyPath.qualifiedColumnName.name],
                onDelete: nil,
                onUpdate: nil,
                match: nil,
                deferrence: nil
            )
            return .init(.foreignKey(fk))
        }
        
        public struct PrimaryKey {
            public var direction: Direction?
            public var conflictResolution: ConflictResolution?
            public var autoIncrement: Bool
            
            public init(
                direction: Direction? = nil,
                conflictResolution: ConflictResolution? = nil,
                autoIncrement: Bool = false
            ) {
                self.direction = direction
                self.conflictResolution = conflictResolution
                self.autoIncrement = autoIncrement
            }
        }
        
        public struct Nullability {
            public var allowNull: Bool
            public var conflictResolution: ConflictResolution?
            
            public init(allowNull: Bool = false, conflictResolution: ConflictResolution? = nil) {
                self.allowNull = allowNull
                self.conflictResolution = conflictResolution
            }
        }
        
        public struct Unique {
            public var conflictResolution: ConflictResolution?
        }
        
        public enum Value {
            case primaryKey(PrimaryKey)
            case nullability(Nullability)
            case unique(Unique)
            case check(Expression)
            case `default`(Expression)
            case collate(String)
            case foreignKey(ForeignKeyReference)
        }
        public var name: String?
        public var value: Value
        
        public init(name: String? = nil, _ value: Value) {
            self.name = name
            self.value = value
        }
    }
}

extension MySQLSerializer {
    func serialize(_ constraint: MySQLQuery.ColumnConstraint, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        if let name = constraint.name {
            sql.append("CONSTRAINT")
            sql.append(escapeString(name))
        }
        sql.append(serialize(constraint.value, &binds))
        return sql.joined(separator: " ")
    }
    
    func serialize(_ value: MySQLQuery.ColumnConstraint.Value, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        switch value {
        case .primaryKey(let primaryKey):
            sql.append("PRIMARY KEY")
            if let direction = primaryKey.direction {
                sql.append(serialize(direction))
            }
            if let conflictResolution = primaryKey.conflictResolution {
                sql.append("ON CONFLICT")
                sql.append(serialize(conflictResolution))
            }
            if primaryKey.autoIncrement {
                sql.append("AUTOINCREMENT")
            }
        case .nullability(let nullability):
            if !nullability.allowNull {
                sql.append("NOT")
            }
            sql.append("NULL")
            if let conflictResolution = nullability.conflictResolution {
                sql.append("ON CONFLICT")
                sql.append(serialize(conflictResolution))
            }
        case .unique(let unique):
            sql.append("UNIQUE")
            if let conflictResolution = unique.conflictResolution {
                sql.append("ON CONFLICT")
                sql.append(serialize(conflictResolution))
            }
        case .check(let expr):
            sql.append("CHECK")
            sql.append("(" + serialize(expr, &binds) + ")")
        case .default(let expr):
            sql.append("DEFAULT")
            sql.append("(" + serialize(expr, &binds) + ")")
        case .collate(let name):
            sql.append("COLLATE")
            sql.append(name)
        case .foreignKey(let reference):
            sql.append(serialize(reference))
        }
        return sql.joined(separator: " ")
    }
}
