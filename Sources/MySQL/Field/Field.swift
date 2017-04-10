import CMySQL
import Core

/// Wraps a MySQL C field struct.
public final class Field {
    public typealias CField = MYSQL_FIELD

    public let cField: CField

    public let name: String

    public init(_ cField: CField) {
        self.cField = cField
        let len = Int(cField.name_length)
        self.name = cField.name.withMemoryRebound(to: Byte.self, capacity: len) { pointer in
            let buff = UnsafeBufferPointer(start: pointer, count: len)
            return Array(buff).makeString()
        }
    }
}
