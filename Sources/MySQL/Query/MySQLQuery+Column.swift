extension MySQLQuery {
    public struct QualifiedColumnName {
        public var table: String?
        public var name: ColumnName
        public var readable: String {
            if let table = table {
                return table + "." + name.string
            } else {
                return name.string
            }
        }
        
        public init(table: String? = nil, name: ColumnName) {
            self.table = table
            self.name = name
        }
    }
    
    public struct ColumnName {
        public var string: String
        public init(_ string: String) {
            self.string = string
        }
    }
}

extension MySQLQuery.QualifiedColumnName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(name: .init(stringLiteral: value))
    }
}

extension MySQLQuery.ColumnName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension MySQLSerializer {
    func serialize(_ columns: [MySQLQuery.ColumnName]) -> String {
        return "(" + columns.map(serialize).joined(separator: ", ") + ")"
    }
    
    func serialize(_ column: MySQLQuery.QualifiedColumnName) -> String {
        switch column.table {
        case .some(let table):
            return escapeString(table) + "." + serialize(column.name)
        case .none:
            return serialize(column.name)
        }
    }
    
    func serialize(_ column: MySQLQuery.ColumnName) -> String {
        return escapeString(column.string)
    }
}
