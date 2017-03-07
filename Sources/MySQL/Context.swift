import Node

public final class MySQLContext: Context {
    internal static let shared = MySQLContext()
    fileprivate init() {}
}

extension Context {
    public var isMySQL: Bool {
        guard let _ = self as? MySQLContext else { return false }
        return true
    }
}
