import MySQLNIO
import SQLKit

extension MySQLDatabase {
    public func sql(
        encoder: MySQLDataEncoder = .init(),
        decoder: MySQLDataDecoder = .init()
    ) -> SQLDatabase {
        _MySQLSQLDatabase(database: self, encoder: encoder, decoder: decoder)
    }
}


private struct _MySQLSQLDatabase {
    let database: MySQLDatabase
    let encoder: MySQLDataEncoder
    let decoder: MySQLDataDecoder
}

extension _MySQLSQLDatabase: SQLDatabase {
    var logger: Logger {
        self.database.logger
    }
    
    var eventLoop: EventLoop {
        self.database.eventLoop
    }
    
    var dialect: SQLDialect {
        MySQLDialect()
    }
    
    func execute(sql query: SQLExpression, _ onRow: @escaping (SQLRow) -> ()) -> EventLoopFuture<Void> {
        let (sql, binds) = self.serialize(query)
        do {
            return try self.database.query(sql, binds.map { encodable in
                return try self.encoder.encode(encodable)
            }, onRow: { row in
                onRow(row.sql(decoder: self.decoder))
            })
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
    }
}
