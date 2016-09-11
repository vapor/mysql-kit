#if os(Linux)
    #if MARIADB
        import CMariaDBLinux
    #else
        import CMySQLLinux
    #endif
#else
    import CMySQLMac
#endif
import Core

/**
    Wraps a MySQL C field struct.
*/
public final class Field {
    public typealias CField = MYSQL_FIELD

    public let cField: CField

    public var name: String {
        var name: String = ""

        let len = Int(cField.name_length)
        cField.name.withMemoryRebound(to: Byte.self, capacity: len) { pointer in
            let buff = UnsafeBufferPointer(start: pointer, count: Int(cField.name_length))
            name = Array(buff).string
        }

        return name
    }

    public init(_ cField: CField) {
        self.cField = cField
    }
}
