extension MySQLQuery.Expression {
    public enum UnaryOperator {
        /// `-`
        case negative
        /// `+`
        case noop
        /// `~`
        case collate
        /// `NOT`
        case not
    }
}


extension MySQLSerializer {
    func serialize(_ expr: MySQLQuery.Expression.UnaryOperator) -> String {
        switch expr {
        case .negative: return "-"
        case .noop: return "+"
        case .collate: return "~"
        case .not: return "!"
        }
    }
}
