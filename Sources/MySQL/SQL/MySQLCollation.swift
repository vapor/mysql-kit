public struct MySQLCollation: SQLCollation {
    public func serialize(_ binds: inout [Encodable]) -> String {
        return "COLLATE"
    }
}
