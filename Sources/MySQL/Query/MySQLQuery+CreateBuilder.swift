extension MySQLQuery {
    public final class CreateTableBuilder {
        public var create: CreateTable
        public let connection: MySQLConnection
        
        init(table: TableName, on connection: MySQLConnection) {
            self.create = .init(table: table, source: .schema(.init(columns: [])))
            self.connection = connection
        }
        
        @discardableResult
        public func column<Table, Value>(
            for keyPath: KeyPath<Table, Value>,
            _ typeName: TypeName? = nil,
            _ constraints: MySQLQuery.ColumnConstraint...
        ) -> Self
            where Table: SQLiteTable
        {
            var schema: CreateTable.Schema
            switch create.source {
            case .schema(let existing): schema = existing
            case .select: schema = .init(columns: [])
            }
            schema.columns.append(.init(
                name: keyPath.qualifiedColumnName.name,
                typeName: typeName,
                constraints: constraints
            ))
            create.source = .schema(schema)
            return self
        }
        
        public func run() -> Future<Void> {
            return connection.query(.createTable(create)).transform(to: ())
        }
    }
}

extension MySQLConnection {
    public func create<Table>(table: Table.Type) -> MySQLQuery.CreateTableBuilder
        where Table: SQLiteTable
    {
        return .init(table: .init(stringLiteral: Table.sqliteTableName), on: self)
    }
}
