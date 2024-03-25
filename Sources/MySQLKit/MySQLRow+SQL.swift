import MySQLNIO
import SQLKit

extension MySQLRow {
    public func sql(decoder: MySQLDataDecoder = .init()) -> any SQLRow {
        MySQLSQLRow(row: self, decoder: decoder)
    }
}

extension MySQLNIO.MySQLRow: @unchecked Sendable {} // Fully qualifying the type name implies @retroactive

struct MissingColumn: Error {
    let column: String
}

private struct MySQLSQLRow: SQLRow {
    let row: MySQLRow
    let decoder: MySQLDataDecoder

    var allColumns: [String] {
        self.row.columnDefinitions.map { $0.name }
    }

    func contains(column: String) -> Bool {
        self.row.columnDefinitions.contains { $0.name == column }
    }

    func decodeNil(column: String) throws -> Bool {
        guard let data = self.row.column(column) else {
            return true
        }
        return data.buffer == nil
    }

    func decode<D: Decodable>(column: String, as: D.Type) throws -> D {
        guard let data = self.row.column(column) else {
            throw MissingColumn(column: column)
        }
        return try self.decoder.decode(D.self, from: data)
    }
}
