/// `ON DUPLICATE KEY UPDATE` or "upsert" clause.
public struct MySQLUpsert: SQLSerializable {
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

extension SQLInsertBuilder where Connectable.Connection.Query.Insert == MySQLInsert {
    /// Adds an `ON DUPLICATE KEY UPDATE` or "upsert" clause to the query.
    ///
    ///     conn.insert(into: Planet.self).value(earth)
    ///          .onConflict(set: earth).run()
    ///
    /// - parameters:
    ///     - value: Encodable value to set if there is a primary key conflict.
    public func onConflict<E>(set value: E) -> Self where E: Encodable {
        let row = SQLQueryEncoder(MySQLExpression.self).encode(value)
        let values = row.map { row -> (MySQLIdentifier, MySQLExpression) in
            return (.identifier(row.key), row.value)
        }
        insert.upsert = .upsert(values)
        return self
    }
}
