import Core

/// Represents row data for a single MySQL column.
public struct MySQLData: Equatable {
    /// The value's data.
    var storage: MySQLDataStorage

    /// Internal init using raw `MySQLBinaryDataStorage`.
    internal init(storage: MySQLDataStorage) {
        self.storage = storage
    }

    /// Creates a new `MySQLData` from a `String`.
    public init(string: String?) {
        let binary = MySQLBinaryData(
            type: .MYSQL_TYPE_VARCHAR,
            isUnsigned: true,
            storage: string.flatMap { .string(.init($0.utf8)) }
        )
        self.storage = .binary(binary)
    }

    /// Creates a new `MySQLData` from `Data`.
    public init(data: Data?) {
        let binary = MySQLBinaryData(
            type: .MYSQL_TYPE_BLOB,
            isUnsigned: true,
            storage: data.flatMap { .string($0) }
        )
        self.storage = .binary(binary)
    }

    /// Creates a new `MySQLData` from JSON-encoded `Data`.
    public init<E>(json: E?) throws where E: Encodable {
        let binary = try MySQLBinaryData(
            type: .MYSQL_TYPE_JSON,
            isUnsigned: true,
            storage: json.flatMap { try .string(JSONEncoder().encode($0)) }
        )
        self.storage = .binary(binary)
    }

    /// Creates a new `MySQLData` from a `FixedWidthInteger`.
    public init<I>(integer: I?) where I: FixedWidthInteger {
        let type: MySQLDataType
        switch I.bitWidth {
        case 8: type = .MYSQL_TYPE_TINY
        case 16: type = .MYSQL_TYPE_SHORT
        case 32: type = .MYSQL_TYPE_LONG
        case 64: type = .MYSQL_TYPE_LONGLONG
        default: fatalError("Unsupported bit-width: \(I.bitWidth)")
        }

        let storage: MySQLBinaryDataStorage?

        if let integer = integer {
            if I.isSigned {
                storage = .integer8(numericCast(integer))
            } else {
                storage = .uinteger8(numericCast(integer))
            }
        } else {
            storage = nil
        }

        let binary = MySQLBinaryData(
            type: type,
            isUnsigned: !I.isSigned,
            storage: storage
        )
        self.storage = .binary(binary)
    }

    /// Creates a new `MySQLData` from `BinaryFloatingPoint`.
    public init<F>(float: F?) where F: BinaryFloatingPoint {
        let type: MySQLDataType
        let bitWidth = F.exponentBitCount + F.significandBitCount + 1
        switch bitWidth {
        case 32: type = .MYSQL_TYPE_FLOAT
        case 64: type = .MYSQL_TYPE_DOUBLE
        default: fatalError("Unsupported float bit width: \(bitWidth)")
        }

        let storage: MySQLBinaryDataStorage?

        switch float {
        case let float as Float: storage = .float4(float)
        case let double as Double: storage = .float8(double)
        case .none: storage = nil
        default: fatalError("Unsupported float type: \(F.self)")
        }

        let binary = MySQLBinaryData(
            type: type,
            isUnsigned: false,
            storage: storage
        )
        self.storage = .binary(binary)
    }

    /// This value's data type
    public var type: MySQLDataType {
        switch storage {
        case .text: return .MYSQL_TYPE_VARCHAR
        case .binary(let binary): return binary.type
        }
    }

    /// Returns `true` if this data is null.
    public var isNull: Bool {
        switch storage {
        case .text(let data): return data == nil
        case .binary(let binary): return binary.storage == nil
        }
    }

    /// Access the value as data.
    public func data() -> Data? {
        switch storage {
        case .text(let data): return data
        case .binary(let binary):
            guard let value = binary.storage else {
                return nil
            }
            switch value {
            case .string(let data): return data
            default: return nil
            }
        }
    }

    /// Access the value as JSON encoded data.
    public func json<D>(_ type: D.Type) throws -> D? where D: Decodable {
        guard let data = self.data() else {
            return nil
        }
        return try JSONDecoder().decode(D.self, from: data)
    }

    /// Access the value as a string.
    public func string(encoding: String.Encoding = .utf8) -> String? {
        switch storage {
        case .text(let data): return data.flatMap { String(data: $0, encoding: .utf8) }
        case .binary(let binary):
            guard let value = binary.storage else {
                return nil
            }
            switch value {
            case .string(let data): return String(data: data, encoding: .utf8)
            default: return nil // support more
            }
        }
    }

    /// Access the value as an fixed-width integer.
    public func integer<I>(_ type: I.Type) throws -> I? where I: FixedWidthInteger {
        switch storage {
        case .text(let data): return data.flatMap { String(data: $0, encoding: .ascii) }.flatMap { I.init($0) }
        case .binary(let binary):
            guard let value = binary.storage else {
                return nil
            }

            func safeCast<J>(_ j: J) throws -> I where J: FixedWidthInteger {
                guard j >= I.min else {
                    throw MySQLError(identifier: "intMin", reason: "Value \(j) too small for \(I.self).", source: .capture())
                }

                guard j <= I.max else {
                    throw MySQLError(identifier: "intMax", reason: "Value \(j) too big for \(I.self).", source: .capture())
                }

                return I(j)
            }

            switch value {
            case .integer1(let int8): return try safeCast(int8)
            case .integer2(let int16): return try safeCast(int16)
            case .integer4(let int32): return try safeCast(int32)
            case .integer8(let int64): return try safeCast(int64)
            case .uinteger1(let uint8): return try safeCast(uint8)
            case .uinteger2(let uint16): return try safeCast(uint16)
            case .uinteger4(let uint32): return try safeCast(uint32)
            case .uinteger8(let uint64): return try safeCast(uint64)
            case .string(let data):
                switch binary.type {
                case .MYSQL_TYPE_VARCHAR, .MYSQL_TYPE_VAR_STRING, .MYSQL_TYPE_STRING: return String(data: data, encoding: .ascii).flatMap { I.init($0) }
                case .MYSQL_TYPE_BIT:
                    if data.count == 1 {
                        return I(data[0])
                    } else {
                        return nil
                    }
                default: return nil // support more

                }
            default: return nil // support more
            }
        }
    }

    /// Access the value as an binary floating point.
    public func float<F>(_ type: F.Type) -> F? where F: BinaryFloatingPoint {
        switch storage {
        case .text(let data): return data.flatMap { String(data: $0, encoding: .ascii) }
            .flatMap { Float80($0) }
            .flatMap { F.init($0) }
        case .binary(let binary):
            guard let value = binary.storage else {
                return nil
            }

            switch value {
            case .integer1(let int8): return F(int8)
            case .integer2(let int16): return F(int16)
            case .integer4(let int32): return F(int32)
            case .integer8(let int64): return F(int64)
            case .uinteger1(let uint8): return F(uint8)
            case .uinteger2(let uint16): return F(uint16)
            case .uinteger4(let uint32): return F(uint32)
            case .uinteger8(let uint64): return F(uint64)
            case .float4(let float): return F(float)
            case .float8(let double): return F(double)
            case .string(let data):
                switch binary.type {
                case .MYSQL_TYPE_VARCHAR, .MYSQL_TYPE_VAR_STRING, .MYSQL_TYPE_STRING:
                    return String(data: data, encoding: .ascii)
                        .flatMap { Float80($0) }
                        .flatMap { F.init($0) }
                default: return nil // TODO: support more
                }
            default: return nil
            }
        }
    }

    /// MYSQL_TYPE_NULL null value (binary).
    public static let null = MySQLData(storage: .binary(.init(type: .MYSQL_TYPE_NULL, isUnsigned: false, storage: nil)))
}


/// Represents a MySQL TEXT column.
public struct MySQLText: MySQLDataConvertible {
    /// This TEXT column's string.
    public var string: String

    /// Creates a new `MySQLText`.
    public init(string: String) {
        self.string = string
    }

    /// See `MySQLDataConvertible.convertToMySQLData()`
    public func convertToMySQLData() throws -> MySQLData {
        return MySQLData(string: string)
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> MySQLText {
        return try MySQLText(string: .convertFromMySQLData(mysqlData))
    }
}

enum MySQLDataStorage: Equatable {
    case text(Data?)
    case binary(MySQLBinaryData)
}

extension MySQLData: CustomStringConvertible {
    /// See `CustomStringConvertible.description`
    public var description: String {
        switch storage {
        case .text(let data):
            if let data = data {
                return String(data: data, encoding: .utf8).flatMap { "string(\"\($0)\")" } ?? "<non utf8 text>"
            } else {
                return "<null>"
            }
        case .binary(let binary):
            if let data = binary.storage {
                switch data {
                case .string(let data):
                    switch binary.type {
                    case .MYSQL_TYPE_VARCHAR, .MYSQL_TYPE_VAR_STRING:
                        return String(data: data, encoding: .utf8).flatMap { "string(\"\($0)\")" } ?? "<non-utf8 string (\(data.count))>"
                    default: return "data(0x\(data.hexEncodedString()))"
                    }
                default: return "\(data)"
                }
            } else {
                return "<null>"
            }
        }
    }
}

extension MySQLData {
    /// Decodes a `MySQLDataConvertible` type from `MySQLData`.
    public func decode<T>(_ type: T.Type) throws -> T where T: MySQLDataConvertible {
        return try T.convertFromMySQLData(self)
    }
}

/// MARK: Convertible

public enum MySQLDataFormat {
    case text
    case binary
}

/// Capable of converting to/from `MySQLData`.
public protocol MySQLDataConvertible {
    /// Convert to `MySQLData`.
    func convertToMySQLData() throws -> MySQLData

    /// Convert from `MySQLData`.
    static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Self
}

extension MySQLData: MySQLDataConvertible {
    /// See `MySQLDataConvertible.convertToMySQLData(format:)`
    public func convertToMySQLData() throws -> MySQLData {
        return self
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> MySQLData {
        return mysqlData
    }
}

extension String: MySQLDataConvertible {
    /// See `MySQLDataConvertible.convertToMySQLData(format:)`
    public func convertToMySQLData() throws -> MySQLData {
        return MySQLData(string: self)
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> String {
        guard let string = mysqlData.string() else {
            throw MySQLError(identifier: "string", reason: "Cannot decode String from MySQLData: \(mysqlData).", source: .capture())
        }
        return string
    }
}

extension FixedWidthInteger {
    /// See `MySQLDataConvertible.convertToMySQLData(format:)`
    public func convertToMySQLData() throws -> MySQLData {
        return MySQLData(integer: self)
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Self {
        guard let int = try mysqlData.integer(Self.self) else {
            throw MySQLError(identifier: "int", reason: "Cannot decode Int from MySQLData: \(mysqlData).", source: .capture())
        }

        return int
    }
}

extension Int8: MySQLDataConvertible { }
extension Int16: MySQLDataConvertible { }
extension Int32: MySQLDataConvertible { }
extension Int64: MySQLDataConvertible { }
extension Int: MySQLDataConvertible { }
extension UInt8: MySQLDataConvertible { }
extension UInt16: MySQLDataConvertible { }
extension UInt32: MySQLDataConvertible { }
extension UInt64: MySQLDataConvertible { }
extension UInt: MySQLDataConvertible { }

extension OptionalType {
    /// See `MySQLDataConvertible.convertToMySQLData(format:)`
    public func convertToMySQLData() throws -> MySQLData {
        if let wrapped = self.wrapped {
            guard let convertible = wrapped as? MySQLDataConvertible else {
                throw MySQLError(identifier: "wrapped", reason: "Could not convert \(WrappedType.self) to MySQLData", source: .capture())
            }
            return try convertible.convertToMySQLData()
        } else {
            let binary = MySQLBinaryData(type: .MYSQL_TYPE_NULL, isUnsigned: false, storage: nil)
            return MySQLData(storage: .binary(binary))
        }
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Self {
        if mysqlData.isNull {
            return makeOptionalType(nil)
        } else {
            guard let convertibleType = WrappedType.self as? MySQLDataConvertible.Type else {
                throw MySQLError(identifier: "wrapped", reason: "Could not convert \(WrappedType.self) to MySQLData", source: .capture())
            }
            let wrapped = try convertibleType.convertFromMySQLData(mysqlData) as! WrappedType
            return makeOptionalType(wrapped)
        }
    }
}

extension Optional: MySQLDataConvertible { }

extension Bool: MySQLDataConvertible {
    /// See `MySQLDataConvertible.convertToMySQLData(format:)`
    public func convertToMySQLData() throws -> MySQLData {
        let binary = MySQLBinaryData(type: .MYSQL_TYPE_TINY, isUnsigned: false, storage: .integer1(self ? 0b1 : 0b0))
        return MySQLData(storage: .binary(binary))
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Bool {
        guard let int = try mysqlData.integer(UInt8.self) else {
            throw MySQLError(identifier: "bool", reason: "Could not parse bool from: \(mysqlData)", source: .capture())
        }

        switch int {
        case 1: return true
        case 0: return false
        default: throw MySQLError(identifier: "bool", reason: "Invalid bool: \(int)", source: .capture())
        }
    }
}

extension BinaryFloatingPoint {
    /// See `MySQLDataConvertible.convertToMySQLData(format:)`
    public func convertToMySQLData() throws -> MySQLData {
        return MySQLData(float: self)
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Self {
        guard let int = mysqlData.float(Self.self) else {
            throw MySQLError(identifier: "float", reason: "Cannot decode Float from MySQLData: \(mysqlData).", source: .capture())
        }

        return int
    }
}

extension Double: MySQLDataConvertible { }
extension Float: MySQLDataConvertible { }

/// MARK: UUID

extension UUID: MySQLDataConvertible {
    /// See `MySQLDataConvertible.convertToMySQLData(format:)`
    public func convertToMySQLData() throws -> MySQLData {
        let binary = MySQLBinaryData(type: .MYSQL_TYPE_STRING, isUnsigned: false, storage: .string(convertToData()))
        return MySQLData(storage: .binary(binary))
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> UUID {
        guard let data = mysqlData.data() else {
            throw MySQLError(identifier: "uuid", reason: "Could not parse UUID from: \(mysqlData)", source: .capture())
        }
        return .convertFromData(data)
    }
}

extension UUID {
    static func convertFromData(_ data: Data) -> UUID {
        return UUID(uuid: data.withUnsafeBytes { pointer in
            return pointer.pointee
        })
    }

    func convertToData() -> Data {
        var uuid = self.uuid
        let size = MemoryLayout.size(ofValue: uuid)
        return withUnsafePointer(to: &uuid) {
            Data(bytes: $0, count: size)
        }
    }
}

/// MARK: Date

/// MYSQL_TIME
///
/// This structure is used to send and receive DATE, TIME, DATETIME, and TIMESTAMP data directly to and from the server.
/// Set the buffer member to point to a MYSQL_TIME structure, and set the buffer_type member of a MYSQL_BIND structure
/// to one of the temporal types (MYSQL_TYPE_TIME, MYSQL_TYPE_DATE, MYSQL_TYPE_DATETIME, MYSQL_TYPE_TIMESTAMP).
///
/// https://dev.mysql.com/doc/refman/5.7/en/c-api-prepared-statement-data-structures.html
struct MySQLTime: Equatable {
    /// The year
    var year: UInt16

    /// The month of the year
    var month: UInt8

    /// The day of the month
    var day: UInt8

    /// The hour of the day
    var hour: UInt8

    /// The minute of the hour
    var minute: UInt8

    /// The second of the minute
    var second: UInt8

    /// The fractional part of the second in microseconds
    var microsecond: UInt32
}

extension Calendar {
    func ccomponent<I>(_ component: Calendar.Component, from date: Date) -> I where I: FixedWidthInteger {
        return numericCast(self.component(component, from: date))
    }
}

extension Date {
    static func convertFromMySQLTime(_ time: MySQLTime) throws -> Date {
        /// For some reason comps.nanosecond is `nil` on linux :(
        let nanosecond: Int
        #if os(macOS)
        nanosecond = numericCast(time.microsecond) * 1_000
        #else
        nanosecond = 0
        #endif

        let comps = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0)!,
            era: nil,
            year: numericCast(time.year),
            month: numericCast(time.month),
            day: numericCast(time.day),
            hour: numericCast(time.hour),
            minute: numericCast(time.minute),
            second: numericCast(time.second),
            nanosecond: numericCast(time.microsecond) * 1_000,
            weekday: nil,
            weekdayOrdinal: nil,
            quarter: nil,
            weekOfMonth: nil,
            weekOfYear: nil,
            yearForWeekOfYear: nil
        )
        guard let date = comps.date else {
            throw MySQLError(identifier: "date", reason: "Could not parse Date from: \(time)", source: .capture())
        }
        
        /// For some reason comps.nanosecond is `nil` on linux :(
        #if os(macOS)
        return date
        #else
        return date.addingTimeInterval(TimeInterval(time.microsecond) / 1_000_000)
        #endif
    }

    func convertToMySQLTime() -> MySQLTime {
        let comps = Calendar(identifier: .gregorian)
            .dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: self)


        /// For some reason comps.nanosecond is `nil` on linux :(
        let microsecond: UInt32
        #if os(macOS)
        microsecond = numericCast((comps.nanosecond ?? 0) / 1_000)
        #else
        microsecond = numericCast(UInt64(timeIntervalSince1970 * 1_000_000) % 1_000_000)
        #endif

        return MySQLTime(
            year: numericCast(comps.year ?? 0),
            month: numericCast(comps.month ?? 0),
            day: numericCast(comps.day ?? 0),
            hour: numericCast(comps.hour ?? 0),
            minute: numericCast(comps.minute ?? 0),
            second: numericCast(comps.second ?? 0),
            microsecond: microsecond
        )
    }
}


extension Date: MySQLDataConvertible {
    /// See `MySQLDataConvertible.convertToMySQLData(format:)`
    public func convertToMySQLData() throws -> MySQLData {
        let binary = MySQLBinaryData(type: .MYSQL_TYPE_TIMESTAMP, isUnsigned: false, storage: .time(convertToMySQLTime()))
        return MySQLData(storage: .binary(binary))
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Date {
        let time: MySQLTime
        switch mysqlData.storage {
        case .binary(let binary):
            guard let storage = binary.storage else {
                throw MySQLError(identifier: "timeNull", reason: "Cannot parse MySQLTime from null.", source: .capture())
            }
            switch storage {
            case .time(let _time): time = _time
            default: throw MySQLError(identifier: "timeBinary", reason: "Parsing MySQLTime from \(binary) is not supported.", source: .capture())
            }
        case .text: throw MySQLError(identifier: "timeText", reason: "Parsing MySQLTime from text is not supported.", source: .capture())
        }

        return try .convertFromMySQLTime(time)
    }
}

