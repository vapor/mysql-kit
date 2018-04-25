import Async

/// A MySQL logger.
public protocol MySQLLogger {
    /// Log the query.
    func log(query: String)
}

extension DatabaseLogger: MySQLLogger {
    public func log(query: String) {
        record(query: query, values: [])
    }
}
