extension MySQLConnection {
    /// Sends a parameterized (a.k.a, prepared or statement protocol query) to the server.
    /// The connection must be authenticated usign `.authenticate(...)` first.
    ///
    /// See `.simpleQuery(...)` for the non-parameterized version.
    ///
    /// - parameters:
    ///     - string: The query string to run. Any values should be represented by `?`.
    ///     - parameters: An array of parameters to bind. The count _must_ equal the number of `?` in the query string.
    ///     - onRow: Handles each row as it is received from the server.
    /// - returns: A future that will complete when the query is finished.
    public func query(_ query: MySQLQuery, _ onRow: @escaping ([MySQLColumn: MySQLData]) throws -> ()) -> Future<Void> {
        var binds: [Encodable] = []
        let string = query.serialize(&binds)
        let params = binds.map { MySQLDataEncoder().encode($0) }
        logger?.record(query: string, values: params.map { $0.description })
        let comPrepare = MySQLComStmtPrepare(query: string)
        var ok: MySQLComStmtPrepareOK?
        var columns: [MySQLColumnDefinition41] = []
        return send([.comStmtPrepare(comPrepare)]) { message in
            switch message {
            case .comStmtPrepareOK(let _ok):
                ok = _ok
                return _ok.numParams == 0 && _ok.numColumns == 0
            case .columnDefinition41(let col):
                let ok = ok!
                columns.append(col)
                if columns.count == ok.numColumns + ok.numParams {
                    return true
                } else {
                    return false
                }
            case .ok, .eof:
                // ignore ok and eof
                return false
            default: throw MySQLError(identifier: "query", reason: "Unsupported message encountered during prepared query: \(message).")
            }
        }.flatMap {
            let ok = ok!
            let comExecute = try MySQLComStmtExecute(
                statementID: ok.statementID,
                flags: 0x00, // which flags?
                values: params.map { data in
                    switch data.storage {
                    case .binary(let binary): return binary
                    case .text: throw MySQLError(identifier: "binaryData", reason: "Binary data required.")
                    }
                }
            )
            let comClose = MySQLPacket.ComStmtClose(statementID: ok.statementID)
            var columns: [MySQLColumnDefinition41] = []
            return self.send([.comStmtExecute(comExecute), .comStmtClose(comClose)]) { message in
                switch message {
                case .columnDefinition41(let col):
                    columns.append(col)
                    return false
                case .binaryResultsetRow(let row):
                    var formatted: [MySQLColumn: MySQLData] = [:]
                    for (i, col) in columns.enumerated() {
                        let data = MySQLData(storage: .binary(row.values[i]))
                        formatted[col.makeMySQLColumn()] = data
                    }
                    try onRow(formatted)
                    return false
                case .ok, .eof:
                    // rows are done
                    return true
                default: throw MySQLError(identifier: "query", reason: "Unsupported message encountered during prepared query: \(message).")
                }
            }
        }
    }
}
