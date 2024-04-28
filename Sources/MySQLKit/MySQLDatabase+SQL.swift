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
    
    func execute(sql query: any SQLExpression, _ onRow: @escaping @Sendable (any SQLRow) -> ()) -> EventLoopFuture<Void> {
        let (sql, binds) = self.serialize(query)
        
        do {
            return try self.database.value.query(
                sql,
                binds.map { try self.encoder.encode($0) },
                onRow: { onRow($0.sql(decoder: self.decoder)) }
            )
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
    }
    
    func execute(sql query: any SQLExpression, _ onRow: @escaping @Sendable (any SQLRow) -> ()) async throws {
        let (sql, binds) = self.serialize(query)
        
        return try await self.database.value.query(
            sql,
            binds.map { try self.encoder.encode($0) },
            onRow: { onRow($0.sql(decoder: self.decoder)) }
        ).get()
    }
    
    func withSession<R>(_ closure: @escaping @Sendable (any SQLDatabase) async throws -> R) async throws -> R {
        try await self.database.value.withConnection { c in
            let sqlDb = c.sql(encoder: self.encoder, decoder: self.decoder)
            
            return sqlDb.eventLoop.makeFutureWithTask { try await closure(sqlDb) }
        }.get()
    }
}
