public struct MySQLDefaultLiteral: SQLDefaultLiteral {
    /// See `SQLDefaultLiteral`.
    public static func `default`() -> MySQLDefaultLiteral {
        return .init()
    }
    
    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        return "DEFAULT"
    }
}
