extension MySQLQuery {
    public struct ForeignKeyReference {
        public struct Deferrence {
            public enum Value {
                case deferred
                case immediate
            }
            public var not: Bool
            public var value: Value?
        }
        
        public enum Action {
            case setNull
            case setDefault
            case cascade
            case restrict
            case noAction
        }
        
        public var foreignTable: TableName
        public var foreignColumns: [ColumnName]
        public var onDelete: Action?
        public var onUpdate: Action?
        public var match: String?
        public var deferrence: Deferrence?
        
        public init(
            foreignTable: TableName,
            foreignColumns: [ColumnName],
            onDelete: Action? = nil,
            onUpdate: Action? = nil,
            match: String? = nil,
            deferrence: Deferrence? = nil
        ) {
            self.foreignTable = foreignTable
            self.foreignColumns = foreignColumns
            self.onDelete = onDelete
            self.onUpdate = onUpdate
            self.match = match
            self.deferrence = deferrence
        }
    }
    
    public struct ForeignKey {
        public var columns: [ColumnName]
        public var reference: ForeignKeyReference
        
        public init(columns: [ColumnName], reference: ForeignKeyReference) {
            self.columns = columns
            self.reference = reference
        }
    }
}

extension MySQLSerializer {
    func serialize(_ foreignKey: MySQLQuery.ForeignKey) -> String {
        var sql: [String] = []
        sql.append("FOREIGN KEY")
        sql.append(serialize(foreignKey.columns))
        sql.append(serialize(foreignKey.reference))
        return sql.joined(separator: " ")
    }
    
    func serialize(_ foreignKey: MySQLQuery.ForeignKeyReference) -> String {
        var sql: [String] = []
        sql.append("REFERENCES")
        sql.append(serialize(foreignKey.foreignTable))
        if !foreignKey.foreignColumns.isEmpty {
            sql.append(serialize(foreignKey.foreignColumns))
        }
        if let onDelete = foreignKey.onDelete {
            sql.append("ON DELETE")
            sql.append(serialize(onDelete))
        }
        if let onUpdate = foreignKey.onUpdate {
            sql.append("ON UPDATE")
            sql.append(serialize(onUpdate))
        }
        if let match = foreignKey.match {
            sql.append("MATCH")
            sql.append(match)
        }
        if let deferrence = foreignKey.deferrence {
            sql.append(serialize(deferrence))
        }
        return sql.joined(separator: " ")
    }
    
    func serialize(_ action: MySQLQuery.ForeignKeyReference.Action) -> String {
        switch action {
        case .cascade: return "CASCADE"
        case .noAction: return "NO ACTION"
        case .restrict: return "RESTRICT"
        case .setDefault: return "SET DEFAULT"
        case .setNull: return "SET NULL"
        }
    }
    
    func serialize(_ deferrence: MySQLQuery.ForeignKeyReference.Deferrence) -> String {
        var sql: [String] = []
        if deferrence.not {
            sql.append("NOT")
        }
        sql.append("DEFERRABLE")
        switch deferrence.value {
        case .none: break
        case .some(let value):
            switch value {
            case .deferred: sql.append("INITIALLY DEFERRED")
            case .immediate: sql.append("INITIALLY IMMEDIATE")
            }
        }
        return sql.joined(separator: " ")
    }
}
