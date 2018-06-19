/// Represents an `ALTER TABLE ...` query.
public struct MySQLAlterTable: SQLAlterTable {
    /// See `SQLAlterTable`.
    public typealias ColumnDefinition = MySQLColumnDefinition
    
    /// See `SQLAlterTable`.
    public typealias TableIdentifier = MySQLTableIdentifier
    
    /// See `SQLAlterTable`.
    public typealias TableConstraint = MySQLTableConstraint
    
    /// See `SQLAlterTable`.
    public static func alterTable(_ table: TableIdentifier) -> MySQLAlterTable {
        return .init(table: table)
    }
    
    /// Name of table to alter.
    public var table: TableIdentifier
    
    /// See `SQLAlterTable`.
    public var columns: [ColumnDefinition]
    
    /// See `SQLAlterTable`.
    public var constraints: [TableConstraint]
    
    
    /// Creates a new `AlterTable`.
    ///
    /// - parameters:
    ///     - table: Name of table to alter.
    public init(table: TableIdentifier) {
        self.table = table
        self.columns = []
        self.constraints = []
    }
    
    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        var sql: [String] = []
        sql.append("ALTER TABLE")
        sql.append(table.serialize(&binds))
        let actions = columns.map { "ADD COLUMN " + $0.serialize(&binds) } + constraints.map { "ADD " + $0.serialize(&binds) }
        sql.append(actions.joined(separator: ", "))
        return sql.joined(separator: " ")
    }
}
