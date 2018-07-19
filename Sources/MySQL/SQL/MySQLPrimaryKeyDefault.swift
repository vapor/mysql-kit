/// MySQL specific `SQLPrimaryKeyDefault`.
public enum MySQLPrimaryKeyDefault: SQLPrimaryKeyDefault {
    /// See `SQLPrimaryKey`.
    public static var `default`: MySQLPrimaryKeyDefault {
        return .autoIncrement
    }
    
    /// Primary key will be automatically generated each time a new row is inserted.
    case autoIncrement
    
    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        switch self {
        case .autoIncrement: return "AUTO_INCREMENT"
        }
    }
}
