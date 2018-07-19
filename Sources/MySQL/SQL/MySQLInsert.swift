/// MySQL specific `SQLInsert`.
public struct MySQLInsert: SQLInsert {
    /// See `SQLInsert`.
    public static func insert(_ table: MySQLTableIdentifier) -> MySQLInsert {
        return self.init(ignore: false, table: table, columns: [], values: [], upsert: nil)
    }
    
    /// See `SQLInsert`.
    public typealias TableIdentifier = MySQLTableIdentifier
    
    /// See `SQLInsert`.
    public typealias ColumnIdentifier = MySQLColumnIdentifier
    
    /// See `SQLInsert`.
    public typealias Expression = MySQLExpression
    
    /// See `SQLInsert`.
    public typealias Upsert = MySQLUpsert
    
    /// If `true`, the query will be an `INSERT IGNORE`.
    public var ignore: Bool
    
    /// Table to insert into.
    public var table: TableIdentifier
    
    /// See `SQLInsert`.
    public var columns: [MySQLColumnIdentifier]
    
    /// See `SQLInsert`.
    public var values: [[MySQLExpression]]
    
    /// See `SQLInsert`.
    public var upsert: MySQLUpsert?
    
    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        var sql: [String] = []
        sql.append("INSERT")
        if ignore {
            sql.append("IGNORE")
        }
        sql.append("INTO")
        sql.append(table.serialize(&binds))
        sql.append("(" + columns.serialize(&binds) + ")")
        sql.append("VALUES")
        sql.append(values.map { "(" + $0.serialize(&binds) + ")"}.joined(separator: ", "))
        if let upsert = self.upsert {
            sql.append(upsert.serialize(&binds))
        }
        return sql.joined(separator: " ")
    }
}
