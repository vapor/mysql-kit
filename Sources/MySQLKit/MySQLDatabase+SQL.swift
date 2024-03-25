import MySQLNIO
import SQLKit

extension MySQLDatabase {
    public func sql(
        encoder: MySQLDataEncoder = .init(),
        decoder: MySQLDataDecoder = .init()
    ) -> any SQLDatabase {
        MySQLSQLDatabase(database: .init(value: self), encoder: encoder, decoder: decoder)
    }
}

private struct MySQLSQLDatabase<D: MySQLDatabase> {
    struct FakeSendable<T>: @unchecked Sendable {
        let value: T
    }
    let database: FakeSendable<D>
    let encoder: MySQLDataEncoder
    let decoder: MySQLDataDecoder
}

extension MySQLSQLDatabase: SQLDatabase {
    var logger: Logger {
        self.database.value.logger
    }
    
    var eventLoop: any EventLoop {
        self.database.value.eventLoop
    }
    
    var dialect: any SQLDialect {
        MySQLDialect()
    }
    
    func execute(sql query: any SQLExpression, _ onRow: @escaping (any SQLRow) -> ()) -> EventLoopFuture<Void> {
        let (sql, binds) = self.serialize(query)
        do {
            return try self.database.value.query(sql, binds.map { encodable in
                return try self.encoder.encode(encodable)
            }, onRow: { row in
                onRow(row.sql(decoder: self.decoder))
            })
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
    }
}
