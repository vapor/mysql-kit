public enum MySQLQuery {
    case alterTable(AlterTable)
    case createTable(CreateTable)
    case delete(Delete)
    case dropTable(DropTable)
    case insert(Insert)
    case raw(String, [MySQLData])
    case select(Select)
    case update(Update)
}

extension MySQLQuery: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .raw(value, [])
    }
}

extension MySQLSerializer {
    func serialize(_ query: MySQLQuery, _ binds: inout [MySQLData]) -> String {
        switch query {
        case .alterTable(let alterTable): return serialize(alterTable, &binds)
        case .createTable(let createTable): return serialize(createTable, &binds)
        case .delete(let delete): return serialize(delete, &binds)
        case .dropTable(let dropTable): return serialize(dropTable)
        case .raw(let sql, let data):
            binds = data
            return sql
        case .select(let select): return serialize(select, &binds)
        case .insert(let insert): return serialize(insert, &binds)
        case .update(let update): return serialize(update, &binds)
        }
    }
}
