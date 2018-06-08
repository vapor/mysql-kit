extension MySQLQuery {
    public final class CreateTableBuilder<Table> where Table: MySQLTable {
        public var create: CreateTable
        public let connection: MySQLConnection
        
        init(table: Table.Type, on connection: MySQLConnection) {
            self.create = .init(table: .init(name: Table.mysqlTableName), source: .schema(.init(columns: [])))
            self.connection = connection
        }
        
        @discardableResult
        public func column<Value>(
            for keyPath: KeyPath<Table, Value>,
            _ typeName: TypeName,
            _ constraints: MySQLQuery.ColumnConstraint...
        ) -> Self {
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
        
        @discardableResult
        public func foreignKey<Foreign, A, B>(
            from local: KeyPath<Table, A>,
            to foreign: KeyPath<Foreign, B>
        ) -> Self
            where Foreign: MySQLTable
        {
            let ref = ForeignKeyReference.init(
                foreignTable: .init(name: Foreign.mysqlTableName),
                foreignColumns: [foreign.qualifiedColumnName.name],
                onDelete: nil,
                onUpdate: nil,
                match: nil,
                deferrence: nil
            )
            let fk = ForeignKey(
                columns: [local.qualifiedColumnName.name],
                reference: ref
            )

            var schema: CreateTable.Schema
            switch create.source {
            case .schema(let existing): schema = existing
            case .select: schema = .init(columns: [])
            }
            schema.tableConstraints.append(.init(.foreignKey(fk)))
            create.source = .schema(schema)
            return self
        }
        
        public func run() -> Future<Void> {
            return connection.query(.createTable(create)).transform(to: ())
        }
    }
}

extension MySQLConnection {
    public func create<Table>(table: Table.Type) -> MySQLQuery.CreateTableBuilder<Table>
        where Table: MySQLTable
    {
        return .init(table: Table.self, on: self)
    }
}
