/// MySQL specific `SQLIdentifier`.
public struct MySQLIdentifier: SQLIdentifier {
    /// See `SQLIdentifier`.
    public static func identifier(_ string: String) -> MySQLIdentifier {
        return self.init(string)
    }
    
    /// See `SQLIdentifier`.
    public var string: String
    
    /// Creates a new `MySQLIdentifier`.
    public init(_ string: String) {
        self.string = string
    }
    
    /// See `ExpressibleByStringLiteral`.
    public init(stringLiteral value: String) {
        self.init(value)
    }
    
    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        return "`\(string)`"
    }
}
