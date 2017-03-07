#if os(Linux)
    #if MARIADB
        import CMariaDBLinux
    #else
        import CMySQLLinux
    #endif
#else
    import CMySQLMac
#endif
import Core

/// Creates `Connection`s to the MySQL database.
public final class Database {
    /// Attempts to establish a connection to a MySQL database
    /// engine running on host.
    ///
    /// - parameter host: May be either a host name or an IP address.
    ///     If host is the string "localhost", a connection to the local host is assumed.
    /// - parameter user: The user's MySQL login ID.
    /// - parameter password: Password for user.
    /// - parameter database: Database name.
    ///     The connection sets the default database to this value.
    /// - parameter port: If port is not 0, the value is used as
    ///     the port number for the TCP/IP connection.
    /// - parameter socket: If socket is not NULL,
    ///     the string specifies the socket or named pipe to use.
    /// - parameter flag: Usually 0, but can be set to a combination of the
    ///     flags at http://dev.mysql.com/doc/refman/5.7/en/mysql-real-connect.html
    /// - parameter encoding: Usually "utf8", but something like "utf8mb4" may be
    ///     used, since "utf8" does not fully implement the UTF8 standard and does
    ///     not support Unicode.
    public init(
        host: String,
        user: String,
        password: String,
        database: String,
        port: UInt = 3306,
        socket: String? = nil,
        flag: UInt = 0,
        encoding: String = "utf8"
    ) throws {
        /// Initializes the server that will
        /// create new connections on each thread
        guard mysql_server_init(0, nil, nil) == 0 else {
            throw MySQLError(.serverInit, reason: "The server failed to initialize.")
        }

        self.host = host
        self.user = user
        self.password = password
        self.database = database
        self.port = UInt32(port)
        self.socket = socket
        self.flag = flag
        self.encoding = encoding
    }

    private let host: String
    private let user: String
    private let password: String
    private let database: String
    private let port: UInt32
    private let socket: String?
    private let flag: UInt
    private let encoding: String


    /// Creates a new connection to
    /// the database that can be reused between executions.
    ///
    /// The connection will close automatically when deinitialized.
    public func makeConnection() throws -> Connection {
        return try Connection(
            host: host,
            user: user,
            password: password,
            database: database,
            port: port,
            socket: socket,
            flag: flag,
            encoding: encoding
        )
    }

    /// Closes the MySQL server.
    deinit {
        mysql_server_end()
    }
}
