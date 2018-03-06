extension MySQLConnection {
    public func simpleQuery(_ string: String) -> Future<[[MySQLColumn: MySQLData]]> {
        var rows: [[MySQLColumn: MySQLData]] = []
        return simpleQuery(string) { row in
            rows.append(row)
        }.map(to: [[MySQLColumn: MySQLData]].self) {
            return rows
        }
    }

    public func simpleQuery(_ string: String, onRow: @escaping ([MySQLColumn: MySQLData]) throws -> ()) -> Future<Void> {
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
                let value: MySQLBinaryValueData? = row.value.flatMap { .string($0) }
                currentRow[col.makeMySQLColumn()] = MySQLData(type: .MYSQL_TYPE_VARCHAR, value: value)
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
