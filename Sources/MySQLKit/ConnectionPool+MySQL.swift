import NIOCore
import Logging
import MySQLNIO

extension EventLoopGroupConnectionPool where Source == MySQLConnectionSource {
    /// Return a `MySQLDatabase` which rotates between the available connection pools.
    ///
    /// - Parameter logger: The logger to assign to the database.
    /// - Returns: A `MySQLDatabase`.
    public func database(logger: Logger) -> any MySQLDatabase {
        EventLoopGroupConnectionPoolMySQLDatabase(pools: self, logger: logger)
    }
}

extension EventLoopConnectionPool where Source == MySQLConnectionSource {
    /// Return a `MySQLDatabase` from this connection pool.
    ///
    /// - Parameter logger: The logger to assign to the database.
    /// - Returns: A `MySQLDatabase`.
    public func database(logger: Logger) -> any MySQLDatabase {
        EventLoopConnectionPoolMySQLDatabase(pool: self, logger: logger)
    }
}

private struct EventLoopGroupConnectionPoolMySQLDatabase: MySQLDatabase {
    let pools: EventLoopGroupConnectionPool<MySQLConnectionSource>
    let logger: Logger

    // See `MySQLDatabase.eventLoop`.
    var eventLoop: any EventLoop {
        self.pools.eventLoopGroup.any()
    }

    // See `MySQLDatabase.send(_:logger:)`.
    func send(_ command: any MySQLCommand, logger: Logger) -> EventLoopFuture<Void> {
        self.pools.withConnection(logger: logger) {
            $0.send(command, logger: logger)
        }
    }

    // See `MySQLDatabase.withConnection(_:)`.
    func withConnection<T>(_ closure: @escaping (MySQLConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        self.pools.withConnection(logger: self.logger, closure)
    }
}

private struct EventLoopConnectionPoolMySQLDatabase: MySQLDatabase {
    let pool: EventLoopConnectionPool<MySQLConnectionSource>
    let logger: Logger

    // See `MySQLDatabase.eventLoop`.
    var eventLoop: any EventLoop {
        self.pool.eventLoop
    }
    
    // See `MySQLDatabase.send(_:logger:)`.
    func send(_ command: any MySQLCommand, logger: Logger) -> EventLoopFuture<Void> {
        self.pool.withConnection(logger: logger) {
            $0.send(command, logger: logger)
        }
    }
    
    // See `MySQLDatabase.withConnection(_:)`.
    func withConnection<T>(_ closure: @escaping (MySQLConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        self.pool.withConnection(logger: self.logger, closure)
    }
}
