extension MySQLQuery {
    public struct Insert {
        public enum Values {
            case values([[Expression]])
            case select(Select)
            case defaults
        }
        
        public struct UpsertClause {
            public enum Action {
                case nothing
                case update(SetValues)
            }
            
            public var indexedColumns: IndexedColumns?
            public var action: Action
        }
        
        public var with: WithClause?
        public var conflictResolution: ConflictResolution?
        public var table: AliasableTableName
        public var columns: [ColumnName]
        public var values: Values
        public var upsert: UpsertClause?
        
        public init(
            with: WithClause? = nil,
            conflictResolution: ConflictResolution? = nil,
            table: AliasableTableName,
            columns: [ColumnName] = [],
            values: Values = .defaults,
            upsert: UpsertClause? = nil
        ) {
            self.with = with
            self.conflictResolution = conflictResolution
            self.table = table
            self.columns = columns
            self.values = values
            self.upsert = upsert
        }
    }
}


extension MySQLSerializer {
    func serialize(_ insert: MySQLQuery.Insert, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        if let with = insert.with {
            sql.append(serialize(with, &binds))
        }
        sql.append("INSERT")
        if let conflictResolution = insert.conflictResolution {
            sql.append("OR")
            sql.append(serialize(conflictResolution))
        }
        sql.append("INTO")
        sql.append(serialize(insert.table))
        if !insert.columns.isEmpty {
            sql.append(serialize(insert.columns))
        }
        sql.append(serialize(insert.values, &binds))
        if let upsert = insert.upsert {
            sql.append(serialize(upsert, &binds))
        }
        return sql.joined(separator: " ")
    }
    
    func serialize(_ values: MySQLQuery.Insert.Values, _ binds: inout [MySQLData]) -> String {
        switch values {
        case .defaults: return "DEFAULT VALUES"
        case .select(let select): return serialize(select, &binds)
        case .values(let values):
            return "VALUES " + values.map {
                return "(" + $0.map { serialize($0, &binds) }.joined(separator: ", ") + ")"
            }.joined(separator: ", ")
        }
    }
    
    func serialize(_ upsert: MySQLQuery.Insert.UpsertClause, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        sql.append("ON CONFLICT")
        if let indexed = upsert.indexedColumns {
            sql.append(serialize(indexed, &binds))
        }
        sql.append("DO")
        sql.append(serialize(upsert.action, &binds))
        return sql.joined(separator: " ")
    }
    
    func serialize(_ action: MySQLQuery.Insert.UpsertClause.Action, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        switch action {
        case .nothing: sql.append("NOTHING")
        case .update(let setValues):
            sql.append("UPDATE")
            sql.append(serialize(setValues, &binds))
        }
        return sql.joined(separator: " ")
    }
}
