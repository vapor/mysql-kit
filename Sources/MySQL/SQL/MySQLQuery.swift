/// MySQL specific `SQLQuery`.
public enum MySQLQuery: SQLQuery {
    /// See `SQLQuery`.
    public typealias AlterTable = MySQLAlterTable
    
    /// See `SQLQuery`.
    public typealias CreateIndex = MySQLCreateIndex
    
    /// See `SQLQuery`.
    public typealias CreateTable = MySQLCreateTable
    
    /// See `SQLQuery`.
    public typealias Delete = MySQLDelete
    
    /// See `SQLQuery`.
    public typealias DropIndex = MySQLDropIndex
    
    /// See `SQLQuery`.
    public typealias DropTable = MySQLDropTable
    
    /// See `SQLQuery`.
    public typealias Insert = MySQLInsert
    
    /// See `SQLQuery`.
    public typealias Select = MySQLSelect
    
    /// See `SQLQuery`.
    public typealias Update = MySQLUpdate
    
    /// See `SQLQuery`.
    public static func alterTable(_ alterTable: AlterTable) -> MySQLQuery {
        return ._alterTable(alterTable)
    }
    
    /// See `SQLQuery`.
    public static func createIndex(_ createIndex: MySQLCreateIndex) -> MySQLQuery {
        return ._createIndex(createIndex)
    }
    
    /// See `SQLQuery`.
    public static func createTable(_ createTable: CreateTable) -> MySQLQuery {
        return ._createTable(createTable)
    }
    
    /// See `SQLQuery`.
    public static func delete(_ delete: Delete) -> MySQLQuery {
        return ._delete(delete)
    }
    
    /// See `SQLQuery`.
    public static func dropIndex(_ dropIndex: MySQLDropIndex) -> MySQLQuery {
        return ._dropIndex(dropIndex)
    }
    
    /// See `SQLQuery`.
    public static func dropTable(_ dropTable: DropTable) -> MySQLQuery {
        return ._dropTable(dropTable)
    }
    
    /// See `SQLQuery`.
    public static func insert(_ insert: Insert) -> MySQLQuery {
        return ._insert(insert)
    }
    
    /// See `SQLQuery`.
    public static func select(_ select: Select) -> MySQLQuery {
        return ._select(select)
    }
    
    /// See `SQLQuery`.
    public static func update(_ update: Update) -> MySQLQuery {
        return ._update(update)
    }
    
    /// See `SQLQuery`.
    public static func raw(_ sql: String, binds: [Encodable]) -> MySQLQuery {
        return ._raw(sql, binds)
    }
    
    /// See `SQLQuery`.
    case _alterTable(AlterTable)
    
    /// See `SQLQuery`.
    case _createIndex(CreateIndex)
    
    /// See `SQLQuery`.
    case _createTable(CreateTable)
    
    /// See `SQLQuery`.
    case _delete(Delete)
    
    /// See `SQLQuery`.
    case _dropIndex(DropIndex)
    
    /// See `SQLQuery`.
    case _dropTable(DropTable)
    
    /// See `SQLQuery`.
    case _insert(Insert)
    
    /// See `SQLQuery`.
    case _select(Select)
    
    /// See `SQLQuery`.
    case _update(Update)
    
    /// See `SQLQuery`.
    case _raw(String, [Encodable])
    
    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        switch self {
        case ._alterTable(let alterTable): return alterTable.serialize(&binds)
        case ._createIndex(let createIndex): return createIndex.serialize(&binds)
        case ._createTable(let createTable): return createTable.serialize(&binds)
        case ._delete(let delete): return delete.serialize(&binds)
        case ._dropIndex(let dropIndex): return dropIndex.serialize(&binds)
        case ._dropTable(let dropTable): return dropTable.serialize(&binds)
        case ._insert(let insert): return insert.serialize(&binds)
        case ._select(let select): return select.serialize(&binds)
        case ._update(let update): return update.serialize(&binds)
        case ._raw(let sql, let values):
            binds = values
            return sql
        }
    }
}

extension MySQLQuery: ExpressibleByStringLiteral {
    /// See `ExpressibleByStringLiteral`.
    public init(stringLiteral value: String) {
        self = ._raw(value, [])
    }
}
