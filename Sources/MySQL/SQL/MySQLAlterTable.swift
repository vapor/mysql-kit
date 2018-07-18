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
    
    /// Specifies the position of a column being added to a table.
    public enum ColumnPosition: SQLSerializable {
        /// Add the column at the beginning of the table.
        case first
        
        /// Add the column after a given column.
        case after(ColumnDefinition.ColumnIdentifier)
        
        /// See `SQLSerializable`.
        func serialize(_ binds: inout [Encodable]) -> String {
            switch self {
            case .first: return "FIRST"
            case .after(let after): return "AFTER " + after.identifier.serialize(&binds)
            }
        }
    }
    
    /// Optional column position settings.
    public var columnPositions: [ColumnDefinition.ColumnIdentifier: ColumnPosition]
    
    /// Creates a new `AlterTable`.
    ///
    /// - parameters:
    ///     - table: Name of table to alter.
    public init(table: TableIdentifier) {
        self.table = table
        self.columns = []
        self.constraints = []
        self.columnPositions = [:]
    }
    
    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        var sql: [String] = []
        sql.append("ALTER TABLE")
        sql.append(table.serialize(&binds))
        let actions = columns.map {
            let sql = "ADD COLUMN " + $0.serialize(&binds)
            if let position = columnPositions[$0.column] {
                return sql + " " + position.serialize(&binds)
            } else {
                return sql
            }
        } + constraints.map { "ADD " + $0.serialize(&binds) }
        sql.append(actions.joined(separator: ", "))
        return sql.joined(separator: " ")
    }
}

extension SQLAlterTableBuilder where Connection.Query.AlterTable == MySQLAlterTable {
    public func order<T, A, B>(_ column: KeyPath<T, A>, after: KeyPath<T, B>) -> Self
        where T: MySQLTable
    {
        alterTable.columnPositions[.keyPath(column)] = .after(.keyPath(after))
        return self
    }
    
    public func order<T, A>(first column: KeyPath<T, A>) -> Self
        where T: MySQLTable
    {
        alterTable.columnPositions[.keyPath(column)] = .first
        return self
    }
}
