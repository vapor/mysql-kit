/// MySQL `COLLATE`.
public struct MySQLCollation: SQLCollation, CustomStringConvertible {
    /// See `CustomStringConvertible`.
    public var description: String {
        return ""
    }
    
    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        return "COLLATE"
    }
}
