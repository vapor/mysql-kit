import CMySQL
import Core

/// Creates `Connection`s to the MySQL database.
public final class Database {
    public let hostname: String
    public let user: String
    public let password: String
    public let database: String
    public let port: UInt32
    public let socket: String?
    public let flag: UInt
    public let encoding: String
    public let optionsGroupName: String
    
    /// Attempts to establish a connection to a MySQL database
    /// engine running on host.
    ///
    /// - parameter hostname: May be either a host name or an IP address.
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
        hostname: String,
        user: String,
        password: String,
        database: String,
        port: UInt = 3306,
        socket: String? = nil,
        flag: UInt = 0,
        encoding: String = "utf8mb4",
        optionsGroupName: String = "vapor"
    ) throws {
        /// Initializes the server that will
        /// create new connections on each thread
        guard mysql_server_init(0, nil, nil) == 0 else {
            throw MySQLError(.serverInit, reason: "The server failed to initialize.")
        }

        self.hostname = hostname
        self.user = user
        self.password = password
        self.database = database
        self.port = UInt32(port)
        self.socket = socket
        self.flag = flag
        self.encoding = encoding
        self.optionsGroupName = optionsGroupName
    }

    /// Creates a new connection to
    /// the database that can be reused between executions.
    ///
    /// The connection will close automatically when deinitialized.
    public func makeConnection() throws -> Connection {
        return try Connection(
            hostname: hostname,
            user: user,
            password: password,
            database: database,
            port: port,
            socket: socket,
            flag: flag,
            encoding: encoding,
            optionsGroupName: optionsGroupName
        )
    }

    /// Closes the MySQL server.
    deinit {
        mysql_server_end()
    }
}
