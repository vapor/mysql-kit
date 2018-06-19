public struct MySQLUpsert: SQLUpsert {
    /// See `SQLUpsert`.
    public typealias Identifier = MySQLIdentifier
    
    /// See `SQLUpsert`.
    public typealias Expression = MySQLExpression
    
    /// See `SQLUpsert`.
    public static func upsert(_ values: [(Identifier, Expression)]) -> MySQLUpsert {
        return self.init(values: values)
    }
    
    /// See `SQLUpsert`.
    public var values: [(Identifier, Expression)]
    
    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        var sql: [String] = []
        sql.append("ON DUPLICATE KEY UPDATE")
        sql.append(values.map { $0.0.serialize(&binds) + " = " + $0.1.serialize(&binds) }.joined(separator: ", "))
        return sql.joined(separator: " ")
    }
}
