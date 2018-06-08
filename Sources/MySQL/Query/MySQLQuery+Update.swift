extension MySQLQuery {
    public struct Update {
        public var with: WithClause? = nil
        public var conflictResolution: ConflictResolution? = nil
        public var table: QualifiedTableName
        public var values: SetValues
        public var predicate: Expression?
        public init(
            with: WithClause? = nil,
            conflictResolution: ConflictResolution? = nil,
            table: QualifiedTableName,
            values: SetValues,
            predicate: Expression? = nil
        ) {
            self.with = with
            self.conflictResolution = conflictResolution
            self.table = table
            self.values = values
            self.predicate = predicate
        }
    }
}
extension MySQLSerializer {
    func serialize(_ update: MySQLQuery.Update, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        if let with = update.with {
            sql.append(serialize(with, &binds))
        }
        sql.append("UPDATE")
        if let conflictResolution = update.conflictResolution {
            sql.append("OR")
            sql.append(serialize(conflictResolution))
        }
        sql.append(serialize(update.table))
        sql.append(serialize(update.values, &binds))
        if let predicate = update.predicate {
            sql.append("WHERE")
            sql.append(serialize(predicate, &binds))
        }
        return sql.joined(separator: " ")
    }
}
