/// MySQL-specific `SQLBoolLiteral`.
public enum MySQLBoolLiteral: SQLBoolLiteral {
    /// See `SQLBoolLiteral`.
    public static var `true`: MySQLBoolLiteral {
        return ._true
    }

    /// See `SQLBoolLiteral`.
    public static var `false`: MySQLBoolLiteral {
        return ._false
    }

    /// See `SQLBoolLiteral`.
    case _true
    
    /// See `SQLBoolLiteral`.
    case _false

    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        switch self {
        case ._true: return "1"
        case ._false: return "0"
        }
    }
}
