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
    
    /// Capability flags
    public let capabilities: MySQLCapabilities

    /// Character set. Default is `utf8mb4_general_ci`.
    public let characterSet: MySQLCharacterSet
    
    /// Connection transport config.
    public let transport: MySQLTransportConfig

    /// Creates a new `MySQLDatabaseConfig`.
    public init(
        hostname: String = "127.0.0.1",
        port: Int = 3306,
        username: String = "vapor",
        password: String? = nil,
        database: String = "vapor",
        capabilities: MySQLCapabilities = .default,
        characterSet: MySQLCharacterSet = .utf8mb4_unicode_ci,
        transport: MySQLTransportConfig = .cleartext
    ) {
        self.hostname = hostname
        self.port = port
        self.username = username
        self.database = database
        self.password = password
        self.capabilities = capabilities
        self.characterSet = characterSet
        self.transport = transport
    }

    /// Creates a `MySQLDatabaseConfig` frome a connection string.
    public init?(
        url urlString: String,
        capabilities: MySQLCapabilities = .default,
        characterSet: MySQLCharacterSet = .utf8mb4_unicode_ci,
        transport: MySQLTransportConfig = .cleartext
    ) throws {
        guard let url = URL(string: urlString) else { return nil }
        self.init(
            hostname: url.host ?? "127.0.0.1",
            port: url.port ?? 3306,
            username: url.user ?? "vapor",
            password: url.password,
            database: url.databaseName ?? "vapor",
            capabilities: capabilities,
            characterSet: characterSet,
            transport: transport
        )
    }
}
