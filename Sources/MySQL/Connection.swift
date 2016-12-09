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
    This structure represents a handle to one database connection.
    It is used for almost all MySQL functions.
    Do not try to make a copy of a MYSQL structure.
    There is no guarantee that such a copy will be usable.
*/
public final class Connection {

    public typealias CConnection = UnsafeMutablePointer<MYSQL>

    public let cConnection: CConnection

    private let lock = Lock()
    
    private let subSecondResolution: Int

    public init(
        host: String,
        user: String,
        password: String,
        database: String,
        port: UInt32,
        socket: String?,
        flag: UInt,
        encoding: String,
        optionsGroupName: String = "vapor",
        subSecondResolution: Int
    ) throws {
        self.subSecondResolution = subSecondResolution
        
        mysql_thread_init()
        cConnection = mysql_init(nil)

        mysql_options(cConnection, MYSQL_READ_DEFAULT_GROUP, optionsGroupName)

        guard mysql_real_connect(cConnection, host, user, password, database, port, socket, flag) != nil else {
            throw Error.connection(error)
        }
        
        mysql_set_character_set(cConnection, encoding)
    }

    @discardableResult
    public func execute(_ query: String, _ values: [NodeRepresentable] = []) throws -> [[String: Node]] {
        var returnable: [[String: Node]] = []
        try lock.locked {
            // Create a pointer to the statement
            // This should only fail if memory is limited.
            guard let statement = mysql_stmt_init(cConnection) else {
                throw Error.statement(error)
            }
            defer {
                mysql_stmt_close(statement)
            }

            // Prepares the created statement
            // This parses `?` in the query and
            // prepares them to attach parameterized bindings.
            guard mysql_stmt_prepare(statement, query, UInt(strlen(query))) == 0 else {
                throw Error.prepare(error)
            }

            // Transforms the `[Value]` array into bindings
            // and applies those bindings to the statement.
            let inputBinds = try Binds(values, subSecondResolution: subSecondResolution)
            guard mysql_stmt_bind_param(statement, inputBinds.cBinds) == 0 else {
                throw Error.inputBind(error)
            }

            // Fetches metadata from the statement which has
            // not yet run.
            if let metadata = mysql_stmt_result_metadata(statement) {
                defer {
                    mysql_free_result(metadata)
                }

                // Parse the fields (columns) that will be returned
                // by this statement.
                let fields: Fields
                do {
                    fields = try Fields(metadata)
                } catch {
                    throw Error.fetchFields(self.error)
                }

                // Use the fields data to create output bindings.
                // These act as buffers for the data that will
                // be returned when the statement is executed.
                let outputBinds = Binds(fields, subSecondResolution: subSecondResolution)

                // Bind the output bindings to the statement.
                guard mysql_stmt_bind_result(statement, outputBinds.cBinds) == 0 else {
                    throw Error.outputBind(error)
                }

                // Execute the statement!
                // The data is ready to be fetched when this completes.
                guard mysql_stmt_execute(statement) == 0 else {
                    throw Error.execute(error)
                }

                var results: [[String: Node]] = []

                // Iterate over all of the rows that are returned.
                // `mysql_stmt_fetch` will continue to return `0`
                // as long as there are rows to be fetched.
                while mysql_stmt_fetch(statement) == 0 {
                    var parsed: [String: Node] = [:]

                    // For each row, loop over all of the fields expected.
                    for (i, field) in fields.fields.enumerated() {

                        // For each field, grab the data from
                        // the output binding buffer and add
                        // it to the parsed results.
                        let output = outputBinds[i]
                        parsed[field.name] = output.value

                    }

                    results.append(parsed)

                    // reset the bindings onto the statement to
                    // signal that they may be reused as buffers
                    // for the next row fetch.
                    guard mysql_stmt_bind_result(statement, outputBinds.cBinds) == 0 else {
                        throw Error.outputBind(error)
                    }
                }
                
                returnable = results
            } else {
                // no data is expected to return from
                // this query, simply execute it.
                guard mysql_stmt_execute(statement) == 0 else {
                    throw Error.execute(error)
                }
                returnable = []
            }
        }

        return returnable
    }


    deinit {
        mysql_close(cConnection)
        mysql_thread_end()
    }

    /**
        Contains the last error message generated
        by this MySQLS connection.
    */
    public var error: String {
        guard let error = mysql_error(cConnection) else {
            return "Unknown"
        }
        return String(cString: error)
    }
    
}

