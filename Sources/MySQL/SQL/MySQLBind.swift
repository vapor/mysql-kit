public protocol MySQLExpressionRepresentable {
    var mySQLExpression: MySQLExpression { get }
}

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
    
    public enum Value {
        case expression(MySQLExpression)
        case encodable(Encodable)
    }
    
    public var value: Value
    
    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        switch value {
        case .expression(let expr): return expr.serialize(&binds)
        case .encodable(let value):
            binds.append(value)
            return "$\(binds.count)"
        }
    }
}
