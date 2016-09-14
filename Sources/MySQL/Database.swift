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
import Foundation


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
        - parameter pool: The number of connections to maintain in the connection pool.


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
        pool: UInt = 8
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
        
        // Clamp connection pool size to range of 1-32
        let poolSize = pool < 1 ? 1 :
            pool > 32 ? 32 :
            pool
        
        self.connectionPool = [Connection]()
        for _ in 0..<poolSize {
            do {
                let conn = try self.makeConnection()
                self.connectionPool.append(conn)
            } catch {
                throw Error.serverInit
            }
        }
    }

    private let host: String
    private let user: String
    private let password: String
    private let database: String
    private let port: UInt32
    private let socket: String?
    private let flag: UInt
    private let encoding: String

    static private var activeLock = Lock()
    
    private var connectionPool: [Connection]

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
    public func execute(_ query: String, _ values: [NodeRepresentable] = []) throws -> [[String: Node]] {
        var result = [[String : Node]]()
        try Database.activeLock.locked {
            let start = Date()
            while connectionPool.count == 0 {
                // Arbitrary 10-second timeout
                if Date().timeIntervalSince1970 - start.timeIntervalSince1970 > 10 {
                    throw Error.connection("The connection pool timed out")
                }
            }
            let connection = connectionPool.removeFirst()
            defer {
                // Recycle connection
                connectionPool.append(connection)
            }
            // TODO: Catch connections that were dropped by the server/interrupted and create a new one
            result = try connection.execute(query, values)
        }
        return result
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
            encoding: encoding
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
