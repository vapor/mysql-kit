import MySQLNIO
import SQLKit

extension MySQLDatabase {
    /// Return an object allowing access to this database via the `SQLDatabase` interface.
    ///
    /// - Parameters:
    ///   - encoder: A ``MySQLDataEncoder`` used to translate bound query parameters into `MySQLData` values.
    ///   - decoder: A ``MySQLDataDecoder`` used to translate `MySQLData` values into output values in `SQLRow`s.
    /// - Returns: An instance of `SQLDatabase` which accesses the same database as `self`.
    public func sql(
        encoder: MySQLDataEncoder = .init(),
        decoder: MySQLDataDecoder = .init(),
        queryLogLevel: Logger.Level? = .debug
    ) -> any SQLDatabase {
        MySQLSQLDatabase(database: .init(value: self), encoder: encoder, decoder: decoder, queryLogLevel: queryLogLevel)
    }
}

/// Wraps a `MySQLDatabase` with the `SQLDatabase` protocol.
private struct MySQLSQLDatabase<D: MySQLDatabase>: SQLDatabase {
    struct FakeSendable<T>: @unchecked Sendable {
        let value: T
    }

    /// The underlying `MySQLDatabase`.
    let database: FakeSendable<D>
    
    /// A ``MySQLDataEncoder`` used to translate bindings into `MySQLData` values.
    let encoder: MySQLDataEncoder
    
    /// A ``MySQLDataDecoder`` used to translate `MySQLData` values into output values in `SQLRow`s.
    let decoder: MySQLDataDecoder

    // See `SQLDatabase.logger`.
    var logger: Logger { self.database.value.logger }
    
    // See `SQLDatabase.eventLoop`.
    var eventLoop: any EventLoop { self.database.value.eventLoop }
    
    // See `SQLDatabase.dialect`.
    var dialect: any SQLDialect { MySQLDialect() }
    
    // See `SQLDatabase.queryLogLevel`.
    let queryLogLevel: Logger.Level?
    
    // See `SQLDatabase.execute(sql:_:)`.
    func execute(sql query: any SQLExpression, _ onRow: @escaping @Sendable (any SQLRow) -> ()) -> EventLoopFuture<Void> {
        let (sql, binds) = self.serialize(query)
        
        if let queryLogLevel = self.queryLogLevel {
            self.logger.log(level: queryLogLevel, "Executing query", metadata: ["sql": .string(sql), "binds": .array(binds.map { .string("\($0)") })])
        }

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
    
    // See `SQLDatabase.execute(sql:_:)`.
    func execute(sql query: any SQLExpression, _ onRow: @escaping @Sendable (any SQLRow) -> ()) async throws {
        let (sql, binds) = self.serialize(query)
        
        if let queryLogLevel = self.queryLogLevel {
            self.logger.log(level: queryLogLevel, "Executing query", metadata: ["sql": .string(sql), "binds": .array(binds.map { .string("\($0)") })])
        }

        return try await self.database.value.query(
            sql,
            binds.map { try self.encoder.encode($0) },
            onRow: { onRow($0.sql(decoder: self.decoder)) }
        ).get()
    }
    
    // See `SQLDatabase.withSession(_:)`.
    func withSession<R>(_ closure: @escaping @Sendable (any SQLDatabase) async throws -> R) async throws -> R {
        try await self.database.value.withConnection { c in
            let sqlDb = c.sql(encoder: self.encoder, decoder: self.decoder)
            
            return sqlDb.eventLoop.makeFutureWithTask { try await closure(sqlDb) }
        }.get()
    }
}
