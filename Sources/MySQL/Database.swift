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


/**
    Holds a `Connection` to the MySQL database.
*/
public final class Database {
    /**
        Attempts to establish a connection to a MySQL database
        engine running on host.
     
        - parameter host: May be either a host name or an IP address.
            If host is the string "localhost", a connection to the local host is assumed.
        - parameter user: The user's MySQL login ID.
        - parameter password: Password for user.
        - parameter database: Database name. 
            The connection sets the default database to this value.
        - parameter port: If port is not 0, the value is used as 
            the port number for the TCP/IP connection.
        - parameter socket: If socket is not NULL, 
            the string specifies the socket or named pipe to use.
        - parameter flag: Usually 0, but can be set to a combination of the 
            flags at http://dev.mysql.com/doc/refman/5.7/en/mysql-real-connect.html
         - parameter encoding: Usually "utf8", but something like "utf8mb4" may be
            used, since "utf8" does not fully implement the UTF8 standard and does
            not support Unicode.
        - parameter subSecondResolution: Usually 0 for no fractional seconds and up to 6
            for microsecond resolution


        - throws: `Error.connection(String)` if the call to
            `mysql_real_connect()` fails.
    */
    public init(
        host: String,
        user: String,
        password: String,
        database: String,
        port: UInt = 3306,
        socket: String? = nil,
        flag: UInt = 0,
        encoding: String = "utf8",
        subSecondResolution: Int = 0
    ) throws {
        try Database.activeLock.locked {
            /// Initializes the server that will
            /// create new connections on each thread
            guard mysql_server_init(0, nil, nil) == 0 else {
                throw Error.serverInit
            }
        }

        self.host = host
        self.user = user
        self.password = password
        self.database = database
        self.port = UInt32(port)
        self.socket = socket
        self.flag = flag
        self.encoding = encoding
        self.subSecondResolution = subSecondResolution
    }

    private let host: String
    private let user: String
    private let password: String
    private let database: String
    private let port: UInt32
    private let socket: String?
    private let flag: UInt
    private let encoding: String
    private let subSecondResolution: Int

    static private var activeLock = Lock()

    /**
        Executes the MySQL query string with parameterized values.
     
        - parameter query: MySQL flavored SQL query string.
        - parameter values: Array of MySQL values to be parameterized.
            The number of Values MUST equal the number of `?` in the query string.
     
        - throws: Various `Database.Error` types.
     
        - returns: An array of `[String: Value]` results.
            May be empty if the call does not produce data.
    */
    @discardableResult
    public func execute(_ query: String, _ values: [NodeRepresentable] = [], _ on: Connection? = nil) throws -> [[String: Node]] {
        // If not connection is supplied, make a new one.
        // This makes thread-safety default.
        let connection: Connection
        if let c = on {
            connection = c
        } else {
            connection = try makeConnection()
        }

        return try connection.execute(query, values)
    }


    /**
        Creates a new thread-safe connection to
        the database that can be reused between executions.

        The connection will close automatically when deinitialized.
    */
    public func makeConnection() throws -> Connection {
        return try Connection(
            host: host,
            user: user,
            password: password,
            database: database,
            port: port,
            socket: socket,
            flag: flag,
            encoding: encoding,
            subSecondResolution: subSecondResolution
        )
    }

    /**
        Closes the connection to MySQL.
    */
    deinit {
        Database.activeLock.locked {
            mysql_server_end()
        }
    }
}
