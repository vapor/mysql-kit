extension MySQLQuery {
    public struct CreateTable {
        public struct Schema {
            public var columns: [ColumnDefinition]
            public var tableConstraints: [TableConstraint]
            public var withoutRowID: Bool
            
            public init(
                columns: [ColumnDefinition],
                tableConstraints: [TableConstraint] = [],
                withoutRowID: Bool = false
            ) {
                self.columns = columns
                self.tableConstraints = tableConstraints
                self.withoutRowID = withoutRowID
            }
        }
        
        public enum Source {
            case schema(Schema)
            case select(Select)
        }
        
        public var temporary: Bool
        public var ifNotExists: Bool
        public var table: TableName
        public var source: Source
        
        public init(
            temporary: Bool = false,
            ifNotExists: Bool = false,
            table: TableName,
            source: Source
        ) {
            self.temporary = temporary
            self.ifNotExists = ifNotExists
            self.table = table
            self.source = source
        }
    }
}

extension MySQLSerializer {
    func serialize(_ create: MySQLQuery.CreateTable, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        sql.append("CREATE")
        if create.temporary {
            sql.append("TEMP")
        }
        sql.append("TABLE")
        if create.ifNotExists {
            sql.append("IF NOT EXISTS")
        }
        sql.append(serialize(create.table))
        sql.append(serialize(create.source, &binds))
        return sql.joined(separator: " ")
    }
    
    func serialize(_ source: MySQLQuery.CreateTable.Source, _ binds: inout [MySQLData]) -> String {
        switch source {
        case .schema(let schema): return serialize(schema, &binds)
        case .select(let select): return "AS " + serialize(select, &binds)
        }
    }
    func serialize(_ schema: MySQLQuery.CreateTable.Schema, _ binds: inout [MySQLData]) -> String {
        var sql: [String] = []
        sql.append("(" + (
            schema.columns.map { serialize($0, &binds) } + schema.tableConstraints.map { serialize($0, &binds) }
        ).joined(separator: ", ") + ")")
        if schema.withoutRowID {
            sql.append("WITHOUT ROWID")
        }
        return sql.joined(separator: " ")
    }
}
