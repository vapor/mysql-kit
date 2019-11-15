extension EventLoopConnectionPool where Source == MySQLConnectionSource {
    public func database(logger: Logger) -> MySQLDatabase {
        _ConnectionPoolMySQLDatabase(pool: self, logger: logger)
    }
}

private struct _ConnectionPoolMySQLDatabase {
    let pool: EventLoopConnectionPool<MySQLConnectionSource>
    let logger: Logger
}

extension _ConnectionPoolMySQLDatabase: MySQLDatabase {
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
