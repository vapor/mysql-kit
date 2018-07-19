/// Convertible to a `MySQLExpression`.
public protocol MySQLExpressionRepresentable {
    /// Self converted to a `MySQLExpression`.
    var mySQLExpression: MySQLExpression { get }
}

/// MySQL specific `SQLBind`.
public struct MySQLBind: SQLBind {
    /// See `SQLBind`.
    public static func encodable<E>(_ value: E) -> MySQLBind
        where E: Encodable
    {
        if let expr = value as? MySQLExpressionRepresentable {
            return self.init(value: .expression(expr.mySQLExpression))
        } else {
            return self.init(value: .encodable(value))
        }
    }
    
    /// Bind value.
    public enum Value {
        /// Nested `MySQLExpression`.
        case expression(MySQLExpression)
        /// Bound `Encodable` value.
        case encodable(Encodable)
    }
    
    /// This bind's value.
    public var value: Value
    
    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        switch value {
        case .expression(let expr): return expr.serialize(&binds)
        case .encodable(let value):
            binds.append(value)
            return "?"
        }
    }
}
