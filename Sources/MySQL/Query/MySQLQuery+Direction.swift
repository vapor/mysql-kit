extension MySQLQuery {
    public enum Direction {
        case ascending
        case descending
    }
}

extension MySQLSerializer {
    func serialize(_ direction: MySQLQuery.Direction) -> String {
        switch direction {
        case .ascending: return "ASC"
        case .descending: return "DESC"
        }
    }
}
