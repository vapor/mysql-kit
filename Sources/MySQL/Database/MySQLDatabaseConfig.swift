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
    let characterSet: MySQLCharacterSet

    /// Creates a new `MySQLDatabaseConfig`.
    public init(hostname: String = "127.0.0.1", port: Int = 3306, username: String, password: String? = nil, database: String, capabilities: MySQLCapabilities = .default, characterSet: MySQLCharacterSet = .utf8_general_ci) {
        self.hostname = hostname
        self.port = port
        self.username = username
        self.database = database
        self.password = password
        self.capabilities = capabilities
        self.characterSet = characterSet
    }
}

extension MySQLDatabaseConfig {
    /// Initialize MySQLDatabase with a DB URL
    public init?(_ databaseURL: String) {
        guard let url = URL(string: databaseURL),
            url.scheme == "mysql",
            url.pathComponents.count == 2,
            let hostname = url.host,
            let username = url.user
            else {return nil}
        
        let password = url.password
        let database = url.pathComponents[1]
        self.init(hostname: hostname, username: username, password: password, database: database)
    }
}
