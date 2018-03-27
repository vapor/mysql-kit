/// Config options for a `MySQLDatabase`
public struct MySQLDatabaseConfig {
    /// Creates a `MySQLDatabaseConfig` with default settings.
    public static func root(database: String) -> MySQLDatabaseConfig {
        return .init(hostname: "127.0.0.1", port: 3306, username: "root", database: database)
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

    /// Creates a new `MySQLDatabaseConfig`.
    public init(hostname: String = "127.0.0.1", port: Int = 3306, username: String, password: String? = nil, database: String) {
        self.hostname = hostname
        self.port = port
        self.username = username
        self.database = database
        self.password = password
    }
}
