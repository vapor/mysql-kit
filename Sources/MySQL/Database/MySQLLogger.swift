import Async

/// A MySQL logger.
public protocol MySQLLogger {
    /// Log the query.
    func log(query: String)
}

extension DatabaseLogger: MySQLLogger {
    /// See MySQLLogger.log
    public func log(query: String) {
        let log = DatabaseLog(query: query)
        record(log: log)
    }
}

