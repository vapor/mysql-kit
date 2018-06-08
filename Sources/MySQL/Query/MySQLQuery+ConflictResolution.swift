extension MySQLQuery {
    public enum ConflictResolution {
        case replace
        case rollback
        case abort
        case fail
        case ignore
    }
}

extension MySQLSerializer {
    func serialize(_ conflictResolution: MySQLQuery.ConflictResolution) -> String {
        switch conflictResolution {
        case .abort: return "ABORT"
        case .fail: return "FAIL"
        case .ignore: return "IGNORE"
        case .replace: return "REPLACE"
        case .rollback: return "ROLLBACK"
        }
    }
}
