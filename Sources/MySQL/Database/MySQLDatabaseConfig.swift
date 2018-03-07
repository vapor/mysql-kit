/// Config options for a `MySQLDatabase`
public struct MySQLDatabaseConfig {
    /// Creates a `PostgreSQLDatabaseConfig` with default settings.
    public static func root(database: String) -> MySQLDatabaseConfig {
        return .init(hostname: "localhost", port: 3306, username: "root", database: database)
    }

    /// Destination hostname.
    public let hostname: String

    /// Destination port.
    public let port: Int

    /// Username to authenticate.
    public let username: String

    /// Optional password to use for authentication.
    public let password: String?

    /// Database name.
    public let database: String

    /// Creates a new `PostgreSQLDatabaseConfig`.
    public init(hostname: String, port: Int, username: String, password: String? = nil, database: String) {
        self.hostname = hostname
        self.port = port
        self.username = username
        self.database = database
        self.password = password
    }
}

