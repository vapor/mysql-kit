extension MySQLConnection {
    /// Sends a simple query (a.k.a, text protocol query) to the server.
    /// The connection must be authenticated usign `.authenticate(...)` first.
    ///
    /// See `.query(...)` for parameterized queries.
    ///
    /// - parameters:
    ///     - string: The query string to run. Any values should be interpolated into the string.
    /// - returns: A future containing the resulting rows.
    public func simpleQuery(_ string: String) -> Future<[[MySQLColumn: MySQLData]]> {
        var rows: [[MySQLColumn: MySQLData]] = []
        return simpleQuery(string) { row in
            rows.append(row)
        }.map(to: [[MySQLColumn: MySQLData]].self) {
            return rows
        }
    }

    /// Sends a simple query (a.k.a, text protocol query) to the server.
    /// The connection must be authenticated usign `.authenticate(...)` first.
    ///
    /// See `.query(...)` for parameterized queries.
    ///
    /// - parameters:
    ///     - string: The query string to run. Any values should be interpolated into the string.
    ///     - onRow: Handles each row as it is received from the server.
    /// - returns: A future that will complete when the query is finished.
    public func simpleQuery(_ string: String, onRow: @escaping ([MySQLColumn: MySQLData]) throws -> ()) -> Future<Void> {
        return operation {
            return self._simpleQuery(string, onRow: onRow)
        }
    }


    /// Private, non-sync query.
    private func _simpleQuery(_ string: String, onRow: @escaping ([MySQLColumn: MySQLData]) throws -> ()) -> Future<Void> {
        let comQuery = MySQLComQuery(query: string)
        var columns: [MySQLColumnDefinition41] = []
        var currentRow: [MySQLColumn: MySQLData] = [:]
        return send([.comQuery(comQuery)]) { message in
            switch message {
            case .columnDefinition41(let col):
                columns.append(col)
                return false
            case .resultSetRow(let row):
                let col = columns[currentRow.keys.count]
                currentRow[col.makeMySQLColumn()] = MySQLData(storage: .text(row.value))
                if currentRow.keys.count >= columns.count {
                    try onRow(currentRow)
                    currentRow = [:]
                }
                return false
            case .ok, .eof: return true
            default: throw MySQLError(identifier: "simpleQuery", reason: "Unsupported message encountered during simple query: \(message).", source: .capture())
            }
        }
    }
}
