extension MySQLQuery {
    public final class AlterTableBuilder {
        public var alter: AlterTable
        public let connection: MySQLConnection
        
        init(table: TableName, on connection: MySQLConnection) {
            self.alter = .init(table: table, value: .rename(table.name))
            self.connection = connection
        }
        
        @discardableResult
        public func rename(to name: String) -> Self {
            alter.value = .rename(name)
            return self
        }
        
        @discardableResult
        public func addColumn<Table, Value>(
            for keyPath: KeyPath<Table, Value>,
            _ typeName: TypeName? = nil,
            _ constraints: MySQLQuery.ColumnConstraint...
        ) -> Self
            where Table: MySQLTable
        {
            alter.value = .addColumn(.init(
                name: keyPath.qualifiedColumnName.name,
                typeName: typeName,
                constraints: constraints
            ))
            return self
        }
        
        public func run() -> Future<Void> {
            return connection.query(.alterTable(alter)).transform(to: ())
        }
    }
}

extension MySQLConnection {
    public func alter<Table>(table: Table.Type) -> MySQLQuery.AlterTableBuilder
        where Table: MySQLTable
    {
        return .init(table: .init(stringLiteral: Table.mysqlTableName), on: self)
    }
}
