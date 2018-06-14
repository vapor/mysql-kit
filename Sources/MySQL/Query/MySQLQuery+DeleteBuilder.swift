extension MySQLQuery {
    public final class DeleteBuilder: MySQLPredicateBuilder {
        public var delete: Delete
        public let connection: MySQLConnection
        public var predicate: MySQLQuery.Expression? {
            get { return delete.predicate }
            set { delete.predicate = newValue }
        }
        
        init(table: QualifiedTableName, on connection: MySQLConnection) {
            self.delete = .init(table: table)
            self.connection = connection
        }
        
        public func run() -> Future<Void> {
            return connection.query(.delete(delete)).transform(to: ())
        }
    }
}

extension MySQLConnection {
    public func delete<Table>(from table: Table.Type) -> MySQLQuery.DeleteBuilder
        where Table: MySQLTable
    {
        return .init(table: .init(table: .init(stringLiteral: Table.mysqlTableName)), on: self)
    }
}
