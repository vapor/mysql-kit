/// Creates connections to an identified MySQL database.
public final class MySQLDatabase: Database {
    /// This database's configuration.
    public let config: MySQLDatabaseConfig

    /// If non-nil, will log queries.
    public var logger: DatabaseLogger?

    /// Creates a new `MySQLDatabase`.
    public init(config: MySQLDatabaseConfig) {
        self.config = config
    }

    /// See `Database.makeConnection()`
    public func makeConnection(on worker: Worker) -> Future<MySQLConnection> {
        let config = self.config
        return Future.flatMap(on: worker) {
            return try MySQLConnection.connect(hostname: config.hostname, port: config.port, on: worker) { error in
                print("[MySQL] \(error)")
            }.flatMap(to: MySQLConnection.self) { client in
                client.logger = self.logger
                return client.authenticate(
                    username: config.username,
                    database: config.database,
                    password: config.password
                ).transform(to: client)
            }
        }
    }
}

extension DatabaseIdentifier {
    /// Default identifier for `MySQLDatabase`.
    public static var mysql: DatabaseIdentifier<MySQLDatabase> {
        return .init("mysql")
    }
}

