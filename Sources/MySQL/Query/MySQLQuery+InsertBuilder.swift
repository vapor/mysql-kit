extension MySQLQuery {
    public final class InsertBuilder {
        public var insert: Insert
        public let connection: MySQLConnection
        
        init(table: AliasableTableName, on connection: MySQLConnection) {
            self.insert = .init(table: table)
            self.connection = connection
        }
        
        @discardableResult
        public func or(_ conflictResolution: MySQLQuery.ConflictResolution) -> Self {
            insert.conflictResolution = conflictResolution
            return self
        }
        
        @discardableResult
        public func defaults() throws -> Self {
            insert.values = .defaults
            return self
        }
        
        @discardableResult
        public func from(_ select: (SelectBuilder) -> ()) throws -> Self {
            let builder = connection.select()
            select(builder)
            insert.values = .select(builder.select)
            return self
        }
        
        @discardableResult
        public func value<E>(_ value: E) throws -> Self
            where E: Encodable
        {
            try values([value])
            return self
        }
        
        @discardableResult
        public func values<E>(_ values: [E]) throws -> Self
            where E: Encodable
        {
            let values = try values.map { try MySQLQueryEncoder().encode($0) }
            if insert.columns.isEmpty {
                insert.columns = values[0].keys.map { ColumnName.init($0) }
            }
            let newValues: [[Expression]] = values.map { .init($0.values) }
            switch insert.values {
            case .defaults, .select:
                insert.values = .values(newValues)
            case .values(let existing):
                insert.values = .values(existing + newValues)
            }
            return self
        }
        
        public func run() -> Future<Void> {
            return connection.query(.insert(insert)).transform(to: ())
        }
    }
}

extension MySQLConnection {
    public func insert<Table>(into table: Table.Type) -> MySQLQuery.InsertBuilder
        where Table: MySQLTable
    {
        return .init(table: .init(stringLiteral: Table.mysqlTableName), on: self)
    }
}
