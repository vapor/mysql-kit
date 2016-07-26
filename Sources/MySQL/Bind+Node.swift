#if os(Linux)
    import CMySQLLinux
#else
    import CMySQLMac
#endif
import Core
import JSON

extension Bind {
    /**
        Parses a MySQL Value object from
        an output binding.
    */
    public var value: Node {
        guard let buffer = cBind.buffer else {
            return nil
        }

        func cast<T>(_ buffer: UnsafeMutablePointer<Void>, _ type: T.Type) -> UnsafeMutablePointer<T> {
            return UnsafeMutablePointer<T>(buffer)
        }

        func unwrap<T>(_ buffer: UnsafeMutablePointer<Void>, _ type: T.Type) -> T {
            return UnsafeMutablePointer<T>(buffer).pointee
        }

        let isNull = cBind.is_null.pointee
        let length = Int(cBind.length.pointee) / sizeof(UInt8.self)

        if isNull == 1 {
            return .null
        } else {
            switch variant {
            case MYSQL_TYPE_STRING,
                 MYSQL_TYPE_VAR_STRING,
                 MYSQL_TYPE_BLOB,
                 MYSQL_TYPE_DECIMAL,
                 MYSQL_TYPE_NEWDECIMAL,
                 MYSQL_TYPE_ENUM,
                 MYSQL_TYPE_SET:
                let buffer = UnsafeMutableBufferPointer(
                    start: cast(buffer, UInt8.self),
                    count: length
                )
                return .string(buffer.string)
            case MYSQL_TYPE_LONG:
                if cBind.is_unsigned == 1 {
                    let uint = unwrap(buffer, UInt32.self)
                    return .number(.uint(UInt(uint)))
                } else {
                    let int = unwrap(buffer, Int32.self)
                    return .number(.int(Int(int)))
                }
            case MYSQL_TYPE_LONGLONG:
                if cBind.is_unsigned == 1 {
                    let uint = unwrap(buffer, UInt64.self)
                    return .number(.uint(UInt(uint)))
                } else {
                    let int = unwrap(buffer, Int64.self)
                    return .number(.int(Int(int)))
                }
            case MYSQL_TYPE_DOUBLE:
                let double = unwrap(buffer, Double.self)
                return .number(.double(double))
            case MYSQL_TYPE_JSON:
                let buffer = UnsafeMutableBufferPointer(
                    start: cast(buffer, UInt8.self),
                    count: length
                )
                let bytes = Array(buffer)

                do {
                    return try JSON(bytes: bytes).makeNode()
                } catch {
                    print("[MySQL] Could not parse JSON.")
                    return .null
                }
            default:
                print("[MySQL] Unsupported type: \(variant).")
                return .null
            }
        }
    }
}

extension Sequence where Iterator.Element == UInt8 {
    var string: String {
        var utf = UTF8()
        var gen = makeIterator()
        var str = String()
        while true {
            switch utf.decode(&gen) {
            case .emptyInput:
                return str
            case .error:
                break
            case .scalarValue(let unicodeScalar):
                str.append(unicodeScalar)
            }
        }
    }
}
