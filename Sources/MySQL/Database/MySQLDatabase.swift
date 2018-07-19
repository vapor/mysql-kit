/// Creates connections to an identified MySQL database.
public final class MySQLDatabase: Database {
    /// This database's configuration.
    public let config: MySQLDatabaseConfig

    /// Creates a new `MySQLDatabase`.
    public init(config: MySQLDatabaseConfig) {
        self.config = config
    }

    /// See `Database`
    public func newConnection(on worker: Worker) -> Future<MySQLConnection> {
        return MySQLConnection.connect(config: self.config, on: worker)
    }
}

extension DatabaseIdentifier {
    /// Default identifier for `MySQLDatabase`.
    public static var mysql: DatabaseIdentifier<MySQLDatabase> {
        return .init("mysql")
    }
}
