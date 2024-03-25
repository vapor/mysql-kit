import NIOCore
import AsyncKit
import Logging
import MySQLNIO

extension EventLoopConnectionPool where Source == MySQLConnectionSource {
    public func database(logger: Logger) -> any MySQLDatabase {
        EventLoopConnectionPoolMySQLDatabase(pool: self, logger: logger)
    }
}

extension EventLoopGroupConnectionPool where Source == MySQLConnectionSource {
    public func database(logger: Logger) -> any MySQLDatabase {
        EventLoopGroupConnectionPoolMySQLDatabase(pools: self, logger: logger)
    }
}

private struct EventLoopGroupConnectionPoolMySQLDatabase: MySQLDatabase {
    let pools: EventLoopGroupConnectionPool<MySQLConnectionSource>
    let logger: Logger

    var eventLoop: any EventLoop {
        self.pools.eventLoopGroup.any()
    }

    func send(_ command: any MySQLCommand, logger: Logger) -> EventLoopFuture<Void> {
        self.pools.withConnection(logger: logger) {
            $0.send(command, logger: logger)
        }
    }

    func withConnection<T>(_ closure: @escaping (MySQLConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        self.pools.withConnection(logger: self.logger, closure)
    }
}

private struct EventLoopConnectionPoolMySQLDatabase: MySQLDatabase {
    let pool: EventLoopConnectionPool<MySQLConnectionSource>
    let logger: Logger

    var eventLoop: any EventLoop {
        self.pool.eventLoop
    }
    
    func send(_ command: any MySQLCommand, logger: Logger) -> EventLoopFuture<Void> {
        self.pool.withConnection(logger: logger) {
            $0.send(command, logger: logger)
        }
    }
    
    func withConnection<T>(_ closure: @escaping (MySQLConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        self.pool.withConnection(logger: self.logger, closure)
    }
}
