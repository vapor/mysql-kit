#if os(Linux)
    #if MARIADB
        import CMariaDBLinux
    #else
        import CMySQLLinux
    #endif
#else
    import CMySQLMac
#endif
/**
    Wraps a pointer to an array of fields
    to ensure proper freeing of allocated memory.
*/
public final class Fields {
    public typealias CMetadata = UnsafeMutablePointer<MYSQL_RES>

    public let fields: [Field]

    public enum Error: Swift.Error {
        case fieldFetch
    }

    /**
        Creates the array of fields from
        the metadata of a statement.
    */
    public init(_ cMetadata: CMetadata, _ conn: Connection) throws {
        guard let cFields = mysql_fetch_fields(cMetadata) else {
            throw conn.lastError
        }

        let fieldsCount = Int(mysql_num_fields(cMetadata))

        var fields: [Field] = []

        for i in 0 ..< fieldsCount {
            let field = Field(cFields[i])
            fields.append(field)
        }

        self.fields = fields
    }
    
}
