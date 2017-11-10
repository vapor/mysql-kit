import CMySQL
import Core
import JSON
import Foundation

extension Bind {
    /// Parses a MySQL Value object from
    /// an output binding.
    public var value: StructuredData {
        guard let buffer = cBind.buffer else {
            return .null
        }

        func cast<T>(_ buffer: UnsafeMutableRawPointer, _ type: T.Type) -> UnsafeMutablePointer<T> {
            return buffer.bindMemory(to: type, capacity: 1)
        }


        func unwrap<T>(_ buffer: UnsafeMutableRawPointer, _ type: T.Type) -> T {
            return buffer.load(as: type)
        }

        // must be stored as function because calling pointee
        // with garbage value will crash
        func len() -> Int {
            return Int(cBind.length.pointee) / MemoryLayout<UInt8>.size
        }

        let isNull = cBind.is_null.pointee

        if isNull == 1 {
            return .null
        } else {
            #if !NOJSON
                if variant == MYSQL_TYPE_JSON {
                    let buffer = UnsafeMutableBufferPointer(
                        start: cast(buffer, UInt8.self),
                        count: len()
                    )
                    let bytes = Array(buffer)

                    do {
                        return try JSON(bytes: bytes)
                            .makeNode(in: MySQLContext.shared)
                            .wrapped
                    } catch {
                        print("[MySQL] Could not parse JSON.")
                        return .null
                    }
                }
            #endif

            switch variant {
            case MYSQL_TYPE_BLOB:
                let buffer = UnsafeMutableBufferPointer(
                    start: cast(buffer, UInt8.self),
                    count: len()
                )
                let bytes = Bytes(buffer)
                return .bytes(bytes)
            case MYSQL_TYPE_STRING,
                 MYSQL_TYPE_VAR_STRING,
                 MYSQL_TYPE_DECIMAL,
                 MYSQL_TYPE_NEWDECIMAL,
                 MYSQL_TYPE_ENUM,
                 MYSQL_TYPE_SET:
                let buffer = UnsafeMutableBufferPointer(
                    start: cast(buffer, UInt8.self),
                    count: len()
                )
                return .string(buffer.makeString())
            case MYSQL_TYPE_LONG:
                if cBind.is_unsigned == 1 {
                    let uint = unwrap(buffer, UInt32.self)
                    return .number(.uint(UInt(uint)))
                } else {
                    let int = unwrap(buffer, Int32.self)
                    return .number(.int(Int(int)))
                }
            case MYSQL_TYPE_SHORT:
                if cBind.is_unsigned == 1 {
                    let uint = unwrap(buffer, UInt16.self)
                    return .number(.uint(UInt(uint)))
                } else {
                    let int = unwrap(buffer, Int16.self)
                    return .number(.int(Int(int)))
                }
            case MYSQL_TYPE_TINY:
                if cBind.is_unsigned == 1 {
                    let uint = unwrap(buffer, UInt8.self)
                    return .number(.uint(UInt(uint)))
                } else {
                    let int = unwrap(buffer, Int8.self)
                    return .number(.int(Int(int)))
                }
            case MYSQL_TYPE_BIT:
                let bit = unwrap(buffer, Bool.self)
                return .bool(bit)
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
            case MYSQL_TYPE_FLOAT:
                let float = unwrap(buffer, Float.self)
                return .number(.double(Double(float)))
            case MYSQL_TYPE_DATE, MYSQL_TYPE_DATETIME, MYSQL_TYPE_TIMESTAMP:
                let time = unwrap(buffer, MYSQL_TIME.self)
                let dateString = "\(time.year.pad(4))-\(time.month.pad(2))-\(time.day.pad(2)) \(time.hour.pad(2)):\(time.minute.pad(2)):\(time.second.pad(2))"
                guard let date = DateFormatter.mysql.date(from: dateString) else {
                    return .string(dateString)
                }
                return .date(date)
            case MYSQL_TYPE_TIME:
                let time = unwrap(buffer, MYSQL_TIME.self)
                return .string("\(time.hour.pad(2)):\(time.minute.pad(2)):\(time.second.pad(2))")
            default:
                print("[MySQL] Unsupported type: \(variant).")
                return .null
            }
        }
    }
}

extension UInt32 {
    func pad(_ n: Int) -> String {
        var string = description

        if string.characters.count >= n {
            return string
        }

        for _ in 0..<(n - string.characters.count) {
            string = "0" + string
        }

        return string
    }
}
