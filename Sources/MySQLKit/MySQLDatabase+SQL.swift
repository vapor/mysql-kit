extension MySQLDatabase {
    public func sql() -> SQLDatabase {
        _MySQLSQLDatabase(database: self)
    }
}


private struct _MySQLSQLDatabase {
    let database: MySQLDatabase
}

extension _MySQLSQLDatabase: SQLDatabase {
    var logger: Logger {
        self.database.logger
    }
    
    var eventLoop: EventLoop {
        self.database.eventLoop
    }
    
    
    func execute(sql query: SQLExpression, _ onRow: @escaping (SQLRow) -> ()) -> EventLoopFuture<Void> {
        var serializer = SQLSerializer(dialect: MySQLDialect())
        query.serialize(to: &serializer)
        do {
            return try self.database.query(serializer.sql, serializer.binds.map { encodable in
                return try MySQLDataEncoder().encode(encodable)
            }, onRow: { row in
                onRow(row)
            })
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
    }
}
