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
    
    // Capability flags
    public let capabilities: MySQLCapabilities

    /// Character set. Default utf8_general_ci
    public let characterSet: MySQLCharacterSet
    
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
    public init(url urlString: String, capabilities: MySQLCapabilities = .default, characterSet: MySQLCharacterSet = .utf8_general_ci) throws {
        guard
            let url = URL(string: urlString),
            let hostname = url.host,
            let port = url.port,
            let username = url.user,
            let database = url.databaseName
        else {
            throw MySQLError(
                identifier: "Bad Connection String",
                reason: "Host could not be parsed",
                possibleCauses: ["Foundation URL is unable to parse the provided connection string"],
                suggestedFixes: ["Check the connection string being passed"],
                source: .capture()
            )
        }

        self.hostname = hostname
        self.port = port
        self.username = username
        self.database = database
        self.password = url.password
        self.capabilities = capabilities
        self.characterSet = characterSet
    }
}
