/// MySQL specific `SQLDropIndex`.
public struct MySQLDropIndex: SQLDropIndex {
    /// See `SQLDropIndex`.
    public var identifier: MySQLIdentifier
    
    /// See `SQLDropIndex`.
    public var table: MySQLTableIdentifier
    
    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        var sql: [String] = []
        sql.append("DROP INDEX")
        sql.append(identifier.serialize(&binds))
        sql.append("ON")
        sql.append(table.serialize(&binds))
        return sql.joined(separator: " ")
    }
}

/// Builds `MySQLDropIndex` queries.
public final class MySQLDropIndexBuilder<Connection>: SQLQueryBuilder
    where Connection: SQLConnection, Connection.Query == MySQLQuery
{
    /// `AlterTable` query being built.
    public var dropIndex: MySQLDropIndex
    
    /// See `SQLQueryBuilder`.
    public var connection: Connection
    
    /// See `SQLQueryBuilder`.
    public var query: MySQLQuery {
        return .dropIndex(dropIndex)
    }
    
    /// Creates a new `SQLCreateIndexBuilder`.
    public init(_ dropIndex: MySQLDropIndex, on connection: Connection) {
        self.dropIndex = dropIndex
        self.connection = connection
    }
}


extension SQLConnection where Query == MySQLQuery {
    /// Drops an index from a table.
    ///
    ///     conn.drop(index: "foo", on: User.self).run()
    ///
    /// - parameters:
    ///     - index: Identifier of index to drop.
    ///     - table: Table to drop index from.
    public func drop<T>(index identifier: MySQLIdentifier, on table: T.Type) -> MySQLDropIndexBuilder<Self>
        where T: MySQLTable
    {
        return .init(MySQLDropIndex(identifier: identifier, table: .table(T.self)), on: self)
    }
}
