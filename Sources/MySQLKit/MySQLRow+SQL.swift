import MySQLNIO
import SQLKit

extension MySQLRow {
    /// Return an `SQLRow` interface to this row.
    ///
    /// - Parameter decoder: A ``MySQLDataDecoder`` used to translate `MySQLData` values into output values in `SQLRow`s.
    /// - Returns: An instance of `SQLRow` which accesses the same data as `self`.
    public func sql(decoder: MySQLDataDecoder = .init()) -> any SQLRow {
        MySQLSQLRow(row: self, decoder: decoder)
    }
}

extension MySQLNIO.MySQLRow: @unchecked Swift.Sendable {} // Fully qualifying the type names implies @retroactive

/// An error used to signal that a column requested from a `MySQLRow` using the `SQLRow` interface is not present.
struct MissingColumn: Error {
    let column: String
}

/// Wraps a `MySQLRow` with the `SQLRow` protocol.
private struct MySQLSQLRow: SQLRow {
    /// The underlying `MySQLRow`.
    let row: MySQLRow
    
    /// A ``MySQLDataDecoder`` used to translate `MySQLData` values into output values.
    let decoder: MySQLDataDecoder

    // See `SQLRow.allColumns`.
    var allColumns: [String] {
        self.row.columnDefinitions.map { $0.name }
    }

    // See `SQLRow.contains(column:)`.
    func contains(column: String) -> Bool {
        self.row.columnDefinitions.contains { $0.name == column }
    }

    // See `SQLRow.decodeNil(column:)`.
    func decodeNil(column: String) throws -> Bool {
        guard let data = self.row.column(column) else {
            return true
        }
        return data.buffer == nil
    }

    // See `SQLRow.decode(column:as:)`.
    func decode<D: Decodable>(column: String, as: D.Type) throws -> D {
        guard let data = self.row.column(column) else {
            throw MissingColumn(column: column)
        }
        return try self.decoder.decode(D.self, from: data)
    }
}
