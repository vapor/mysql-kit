import NIOCore
import AsyncKit
import Logging
import MySQLNIO

extension EventLoopConnectionPool where Source == MySQLConnectionSource {
    public func database(logger: Logger) -> MySQLDatabase {
        _EventLoopConnectionPoolMySQLDatabase(pool: self, logger: logger)
    }
}

extension EventLoopGroupConnectionPool where Source == MySQLConnectionSource {
    public func database(logger: Logger) -> MySQLDatabase {
        _EventLoopGroupConnectionPoolMySQLDatabase(pools: self, logger: logger)
    }
}

private struct _EventLoopGroupConnectionPoolMySQLDatabase {
    let pools: EventLoopGroupConnectionPool<MySQLConnectionSource>
    let logger: Logger
}

extension _EventLoopGroupConnectionPoolMySQLDatabase: MySQLDatabase {
    var eventLoop: EventLoop {
        self.pools.eventLoopGroup.next()
    }

    func send(_ command: MySQLCommand, logger: Logger) -> EventLoopFuture<Void> {
        self.pools.withConnection(logger: logger) {
            $0.send(command, logger: logger)
        }
    }

    func withConnection<T>(_ closure: @escaping (MySQLConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        self.pools.withConnection(logger: self.logger, closure)
    }
}

private struct _EventLoopConnectionPoolMySQLDatabase {
    let pool: EventLoopConnectionPool<MySQLConnectionSource>
    let logger: Logger
}

extension _EventLoopConnectionPoolMySQLDatabase: MySQLDatabase {
    var eventLoop: EventLoop {
        self.pool.eventLoop
    }
    
    func send(_ command: MySQLCommand, logger: Logger) -> EventLoopFuture<Void> {
        self.pool.withConnection(logger: logger) {
            $0.send(command, logger: logger)
        }
    }
    
    func withConnection<T>(_ closure: @escaping (MySQLConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        self.pool.withConnection(logger: self.logger, closure)
    }
}
