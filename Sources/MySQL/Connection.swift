import CMySQL
import Core
import Foundation

/// This structure represents a handle to one database connection.
/// It is used for almost all MySQL functions.
/// Do not try to make a copy of a MYSQL structure.
/// There is no guarantee that such a copy will be usable.
public final class Connection {

    public typealias CConnection = UnsafeMutablePointer<MYSQL>

    public let cConnection: CConnection
    public var isClosed: Bool

    init(
        host: String,
        user: String,
        password: String,
        database: String,
        port: UInt32 = 3306,
        socket: String? = nil,
        flag: UInt = 0,
        encoding: String = "utf8mb4",
        optionsGroupName: String = "vapor"
    ) throws {
        mysql_thread_init()
        cConnection = mysql_init(nil)

        mysql_options(cConnection, MYSQL_READ_DEFAULT_GROUP, optionsGroupName)

        guard mysql_real_connect(
            cConnection,
            host,
            user,
            password,
            database,
            port,
            socket,
            flag
        ) != nil else {
            throw MySQLError(.connection, reason: "Connection failed.")
        }
        
        mysql_set_character_set(cConnection, encoding)
        isClosed = false
    }
    
    public func transaction(_ closure: () throws -> Void) throws {
        // required by transactions, but I don't want to open the old
        // MySQL query API to the public as it would be a burden to maintain.
        func manual(_ query: String) throws {
            guard mysql_query(cConnection, query) == 0 else {
                throw lastError
            }
        }
        
        try manual("START TRANSACTION")
        
        do {
            try closure()
        } catch {
            // rollback changes and then rethrow the error
            try manual("ROLLBACK")
            throw error
        }

        try manual("COMMIT")
    }

    @discardableResult
    public func execute(_ query: String, _ values: [Node] = []) throws -> Node {
        // Create a pointer to the statement
        // This should only fail if memory is limited.
        guard let statement = mysql_stmt_init(cConnection) else {
            throw lastError
        }
        defer {
            mysql_stmt_close(statement)
        }

        // Prepares the created statement
        // This parses `?` in the query and
        // prepares them to attach parameterized bindings.
        guard mysql_stmt_prepare(statement, query, UInt(strlen(query))) == 0 else {
            throw lastError
        }

        // Transforms the `[Value]` array into bindings
        // and applies those bindings to the statement.
        let inputBinds = try Binds(values)
        guard mysql_stmt_bind_param(statement, inputBinds.cBinds) == 0 else {
            throw lastError
        }

        // Fetches metadata from the statement which has
        // not yet run.
        guard let metadata = mysql_stmt_result_metadata(statement) else {
            // no data is expected to return from
            // this query, simply execute it.
            guard mysql_stmt_execute(statement) == 0 else {
                throw lastError
            }

            return .null
        }

        defer {
            mysql_free_result(metadata)
        }

        // Parse the fields (columns) that will be returned
        // by this statement.
        let fields = try Fields(metadata, self)

        // Use the fields data to create output bindings.
        // These act as buffers for the data that will
        // be returned when the statement is executed.
        let outputBinds = Binds(fields)

        // Bind the output bindings to the statement.
        guard mysql_stmt_bind_result(statement, outputBinds.cBinds) == 0 else {
            throw lastError
        }

        // Execute the statement!
        // The data is ready to be fetched when this completes.
        guard mysql_stmt_execute(statement) == 0 else {
            throw lastError
        }

        var results: [StructuredData] = []

        // This single dictionary is reused for all rows in the result set
        // to avoid the runtime overhead of (de)allocating one per row.
        var parsed: [String: StructuredData] = [:]

        // Iterate over all of the rows that are returned.
        // `mysql_stmt_fetch` will continue to return `0`
        // as long as there are rows to be fetched.
        while mysql_stmt_fetch(statement) == 0 {
            // For each row, loop over all of the fields expected.
            for (i, field) in fields.fields.enumerated() {

                // For each field, grab the data from
                // the output binding buffer and add
                // it to the parsed results.
                let output = outputBinds[i]
                parsed[field.name] = output.value

            }

            results.append(
                .object(parsed)
            )

            // reset the bindings onto the statement to
            // signal that they may be reused as buffers
            // for the next row fetch.
            guard mysql_stmt_bind_result(statement, outputBinds.cBinds) == 0 else {
                throw lastError
            }
        }

        return Node(
            .array(results),
            in: MySQLContext.shared
        )
    }
    
    public func ping() -> Bool {
        return mysql_ping(cConnection) != 0
    }

    deinit {
        mysql_close(cConnection)
        mysql_thread_end()
    }

    /// Contains the last error message generated
    /// by this MySQLS connection.
    public var lastError: MySQLError {
        let e = MySQLError(self)
        
        switch e.code {
        case .serverGone, .serverLost, .serverLostExtended:
            isClosed = true
        default:
            break
        }
        
        return e
    }
}


extension Connection {
    @discardableResult
    public func execute(_ query: String, _ representable: [NodeRepresentable]) throws -> Node {
        let values = try representable.map {
            return try $0.makeNode(in: MySQLContext.shared)
        }
        
        return try execute(query, values)
    }
}

