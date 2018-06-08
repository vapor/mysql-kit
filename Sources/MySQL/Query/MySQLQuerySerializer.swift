extension MySQLQuery {
    public func serialize(_ binds: inout [MySQLData]) -> String {
        return MySQLSerializer().serialize(self, &binds)
    }
}

struct MySQLSerializer {
    init() { }
    
    func escapeString(_ string: String) -> String {
        return "`" + string + "`"
    }
}

public protocol SQLitePredicateBuilder: class {
    var connection: MySQLConnection { get }
    var predicate: MySQLQuery.Expression? { get set }
}

extension SQLitePredicateBuilder {
    public func `where`(_ expressions: MySQLQuery.Expression...) -> Self {
        for expression in expressions {
            self.predicate &= expression
        }
        return self
    }
    
    @discardableResult
    public func `where`(or expressions: MySQLQuery.Expression...) -> Self {
        for expression in expressions {
            self.predicate |= expression
        }
        return self
    }
    
    public func `where`(group: (SQLitePredicateBuilder) throws -> ()) rethrows -> Self {
        let builder = MySQLQuery.SelectBuilder(on: connection)
        try group(builder)
        switch (self.predicate, builder.select.predicate) {
        case (.some(let a), .some(let b)):
            self.predicate = a && .expressions([b])
        case (.none, .some(let b)):
            self.predicate = .expressions([b])
        case (.some, .none), (.none, .none): break
        }
        return self
    }
}
