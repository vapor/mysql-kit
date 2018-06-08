extension MySQLQuery {
    public final class DropTableBuilder {
        public var drop: DropTable
        public let connection: MySQLConnection
        
        init(table: TableName, on connection: MySQLConnection) {
            self.drop = .init(table: table)
            self.connection = connection
        }
        
        @discardableResult
        public func ifExists() -> Self {
            drop.ifExists = true
            return self
        }
        
        public func run() -> Future<Void> {
            return connection.query(.dropTable(drop)).transform(to: ())
        }
    }
}

extension MySQLConnection {
    public func drop<Table>(table: Table.Type) -> MySQLQuery.DropTableBuilder
        where Table: SQLiteTable
    {
        return .init(table: .init(stringLiteral: Table.sqliteTableName), on: self)
    }
}
