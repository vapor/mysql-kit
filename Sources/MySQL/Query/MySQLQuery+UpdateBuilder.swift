extension MySQLQuery {
    public final class UpdateBuilder: SQLitePredicateBuilder {
        public var update: Update
        public let connection: MySQLConnection
        public var predicate: MySQLQuery.Expression? {
            get { return update.predicate }
            set { update.predicate = newValue }
        }
        
        init(table: QualifiedTableName, on connection: MySQLConnection) {
            self.update = .init(table: table, values: .init(columns: []))
            self.connection = connection
        }
        
        @discardableResult
        public func or(_ conflictResolution: MySQLQuery.ConflictResolution) -> Self {
            update.conflictResolution = conflictResolution
            return self
        }
        
        @discardableResult
        public func set<E>(_ value: E) throws -> Self
            where E: Encodable
        {
            for (col, val) in try MySQLQueryEncoder().encode(value) {
                update.values.columns.append(.init(columns: [.init(col)], value: val))
            }
            return self
        }
        
        public func run() -> Future<Void> {
            return connection.query(.update(update)).transform(to: ())
        }
    }
}

extension MySQLConnection {
    public func update<Table>(_ table: Table.Type) -> MySQLQuery.UpdateBuilder
        where Table: SQLiteTable
    {
        return .init(table: .init(table: .init(stringLiteral: Table.sqliteTableName)), on: self)
    }
}
