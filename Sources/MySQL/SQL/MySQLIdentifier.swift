public struct MySQLIdentifier: SQLIdentifier {
    /// See `SQLIdentifier`.
    public static func identifier(_ string: String) -> MySQLIdentifier {
        return self.init(string: string)
    }
    
    /// See `SQLIdentifier`.
    public var string: String
    
    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        return "`\(string)`"
    }
}
