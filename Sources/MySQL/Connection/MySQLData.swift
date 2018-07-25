import Core

/// Represents row data for a single MySQL column.
public struct MySQLData: Equatable, Encodable {
    internal enum Storage: Equatable {
        case text(Data?)
        case binary(MySQLBinaryData)
    }
    
    /// The value's data.
    internal var storage: Storage

    /// Internal init using raw `MySQLBinaryDataStorage`.
    internal init(storage: Storage) {
        self.storage = storage
    }

    /// Creates a new `MySQLData` from a `String`.
    public init(string: String?) {
        let binary = MySQLBinaryData(
            type: .MYSQL_TYPE_VARCHAR,
            isUnsigned: true,
            storage: string.flatMap { .string(.init($0.utf8)) } ?? .null
        )
        self.storage = .binary(binary)
    }

    /// Creates a new `MySQLData` from `Data`.
    public init(data: Data?) {
        let binary = MySQLBinaryData(
            type: .MYSQL_TYPE_BLOB,
            isUnsigned: true,
            storage: data.flatMap { .string($0) } ?? .null
        )
        self.storage = .binary(binary)
    }

    /// Creates a new `MySQLData` from JSON-encoded `Data`.
    public init<E>(json: E?) where E: Encodable {
        let storage: MySQLBinaryDataStorage
        do {
            storage = try json.flatMap { try .string(JSONEncoder().encode($0)) } ?? .null
        } catch {
            ERROR("Could not encode JSON to MySQLData: \(error)")
            storage = .null
        }
        
        let binary = MySQLBinaryData(
            type: .MYSQL_TYPE_JSON,
            isUnsigned: true,
            storage: storage
        )
        self.storage = .binary(binary)
    }

    /// Creates a new `MySQLData` from a `FixedWidthInteger`.
    public init<I>(integer: I?) where I: FixedWidthInteger {
        let type: MySQLBinaryDataType
        switch I.bitWidth {
        case 8: type = .MYSQL_TYPE_TINY
        case 16: type = .MYSQL_TYPE_SHORT
        case 32: type = .MYSQL_TYPE_LONG
        case 64: type = .MYSQL_TYPE_LONGLONG
        default: fatalError("Unsupported bit-width: \(I.bitWidth)")
        }

        let storage: MySQLBinaryDataStorage?

        if let integer = integer {
            switch (I.bitWidth, I.isSigned) {
                case ( 8, true):  storage = .integer1(numericCast(integer))
                case ( 8, false): storage = .uinteger1(numericCast(integer))
                case (16, true):  storage = .integer2(numericCast(integer))
                case (16, false): storage = .uinteger2(numericCast(integer))
                case (32, true):  storage = .integer4(numericCast(integer))
                case (32, false): storage = .uinteger4(numericCast(integer))
                case (64, true):  storage = .integer8(numericCast(integer))
                case (64, false): storage = .uinteger8(numericCast(integer))
                default: fatalError("Unsupported bit-width: \(I.bitWidth)")
            }
        } else {
            storage = nil
        }

        let binary = MySQLBinaryData(
            type: type,
            isUnsigned: !I.isSigned,
            storage: storage ?? .null
        )
        self.storage = .binary(binary)
    }

    /// Creates a new `MySQLData` from `BinaryFloatingPoint`.
    public init<F>(float: F?) where F: BinaryFloatingPoint {
        let type: MySQLBinaryDataType
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
            storage: storage ?? .null
        )
        self.storage = .binary(binary)
    }

    /// This value's data type
    internal var type: MySQLBinaryDataType {
        switch storage {
        case .text: return .MYSQL_TYPE_VARCHAR
        case .binary(let binary): return binary.type
        }
    }

    /// Returns `true` if this data is null.
    public var isNull: Bool {
        switch storage {
        case .text(let data): return data == nil
        case .binary(let binary):
            switch binary.storage {
            case .null: return true
            default: return false
            }
        }
    }

    /// Access the value as data.
    public func data() -> Data? {
        switch storage {
        case .text(let data): return data
        case .binary(let binary):
            switch binary.storage {
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
            switch binary.storage {
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
            func safeCast<J>(_ j: J) throws -> I where J: FixedWidthInteger {
                guard j >= I.min else {
                    throw MySQLError(identifier: "intMin", reason: "Value \(j) too small for \(I.self).")
                }

                guard j <= I.max else {
                    throw MySQLError(identifier: "intMax", reason: "Value \(j) too big for \(I.self).")
                }

                return I(j)
            }

            switch binary.storage {
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
                case .MYSQL_TYPE_VARCHAR, .MYSQL_TYPE_VAR_STRING, .MYSQL_TYPE_STRING, .MYSQL_TYPE_DECIMAL, .MYSQL_TYPE_NEWDECIMAL: return String(data: data, encoding: .ascii).flatMap { I.init($0) }
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
            switch binary.storage {
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
                case .MYSQL_TYPE_VARCHAR, .MYSQL_TYPE_VAR_STRING, .MYSQL_TYPE_STRING, .MYSQL_TYPE_DECIMAL, .MYSQL_TYPE_NEWDECIMAL:
                    return String(data: data, encoding: .ascii)
                        .flatMap { Float80($0) }
                        .flatMap { F.init($0) }
                default: return nil // TODO: support more
                }
            default: return nil
            }
        }
    }
    
    /// See `Encodable`.
    public func encode(to encoder: Encoder) throws {
        var single = encoder.singleValueContainer()
        switch storage {
        case .binary(let binary):
            switch binary.storage {
            case .float4(let value): try single.encode(value)
            case .float8(let value): try single.encode(value)
            case .integer1(let value): try single.encode(value)
            case .integer2(let value): try single.encode(value)
            case .integer4(let value): try single.encode(value)
            case .integer8(let value): try single.encode(value)
            case .uinteger1(let value): try single.encode(value)
            case .uinteger2(let value): try single.encode(value)
            case .uinteger4(let value): try single.encode(value)
            case .uinteger8(let value): try single.encode(value)
            case .null: try single.encodeNil()
            case .string(let data): try single.encode(data)
            case .time(let time): try single.encode(Date.convertFromMySQLTime(time))
            }
        case .text(let data):
            if let data = data {
                try single.encode(data)
            } else {
                try single.encodeNil()
            }
        }
    }

    /// MYSQL_TYPE_NULL null value (binary).
    public static let null = MySQLData(storage: .binary(.init(type: .MYSQL_TYPE_NULL, isUnsigned: false, storage: .null)))
}

extension MySQLData: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(string: value)
    }
}

extension MySQLData: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(integer: value)
    }
}

extension MySQLData: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.init(integer: value ? UInt8(1) : 0)
    }
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
    public func convertToMySQLData() -> MySQLData {
        return MySQLData(string: string)
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> MySQLText {
        return try MySQLText(string: .convertFromMySQLData(mysqlData))
    }
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
            switch binary.storage {
            case .string(let data):
                switch binary.type {
                case .MYSQL_TYPE_VARCHAR, .MYSQL_TYPE_VAR_STRING:
                    return String(data: data, encoding: .utf8).flatMap { "string(\"\($0)\")" } ?? "<non-utf8 string (\(data.count))>"
                default: return "data(0x\(data.hexEncodedString()))"
                }
            case .null: return "null"
            default: return "\(binary.storage)"
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

/// MySQL wire protocol data format.
public enum MySQLDataFormat {
    /// Text (string) format.
    case text
    /// Binary, MySQL-specific format.
    case binary
}

/// Capable of converting to/from `MySQLData`.
public protocol MySQLDataConvertible {
    /// Convert to `MySQLData`.
    func convertToMySQLData() -> MySQLData

    /// Convert from `MySQLData`.
    static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Self
}

extension MySQLData: MySQLDataConvertible {
    /// See `MySQLDataConvertible`.
    public func convertToMySQLData() -> MySQLData {
        return self
    }

    /// See `MySQLDataConvertible`.
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> MySQLData {
        return mysqlData
    }
}

extension String: MySQLDataConvertible {
    /// See `MySQLDataConvertible`.
    public func convertToMySQLData() -> MySQLData {
        return MySQLData(string: self)
    }

    /// See `MySQLDataConvertible`.
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> String {
        guard let string = mysqlData.string() else {
            throw MySQLError(identifier: "string", reason: "Cannot decode String from MySQLData: \(mysqlData).")
        }
        return string
    }
}

extension FixedWidthInteger {
    /// See `MySQLDataConvertible`.
    public func convertToMySQLData() -> MySQLData {
        return MySQLData(integer: self)
    }

    /// See `MySQLDataConvertible`.
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Self {
        guard let int = try mysqlData.integer(Self.self) else {
            throw MySQLError(identifier: "int", reason: "Cannot decode Int from MySQLData: \(mysqlData).")
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
    /// See `MySQLDataConvertible`.
    public func convertToMySQLData() -> MySQLData {
        if let wrapped = self.wrapped {
            guard let convertible = wrapped as? MySQLDataConvertible else {
                fatalError("Could not convert \(WrappedType.self) to MySQLData")
            }
            return convertible.convertToMySQLData()
        } else {
            let binary = MySQLBinaryData(type: .MYSQL_TYPE_NULL, isUnsigned: false, storage: .null)
            return MySQLData(storage: .binary(binary))
        }
    }

    /// See `MySQLDataConvertible`.
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Self {
        if mysqlData.isNull {
            return makeOptionalType(nil)
        } else {
            guard let convertibleType = WrappedType.self as? MySQLDataConvertible.Type else {
                throw MySQLError(identifier: "wrapped", reason: "Could not convert \(WrappedType.self) to MySQLData")
            }
            let wrapped = try convertibleType.convertFromMySQLData(mysqlData) as! WrappedType
            return makeOptionalType(wrapped)
        }
    }
}

extension Optional: MySQLDataConvertible { }

extension Bool: MySQLDataConvertible {
    /// See `MySQLDataConvertible`.
    public func convertToMySQLData() -> MySQLData {
        let binary = MySQLBinaryData(type: .MYSQL_TYPE_TINY, isUnsigned: false, storage: .integer1(self ? 0b1 : 0b0))
        return MySQLData(storage: .binary(binary))
    }

    /// See `MySQLDataConvertible`.
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Bool {
        guard let int = try mysqlData.integer(UInt8.self) else {
            throw MySQLError(identifier: "bool", reason: "Could not parse bool from: \(mysqlData)")
        }

        switch int {
        case 1: return true
        case 0: return false
        default: throw MySQLError(identifier: "bool", reason: "Invalid bool: \(int)")
        }
    }
}

extension BinaryFloatingPoint {
    /// See `MySQLDataConvertible`.
    public func convertToMySQLData() -> MySQLData {
        return MySQLData(float: self)
    }

    /// See `MySQLDataConvertible`.
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Self {
        guard let int = mysqlData.float(Self.self) else {
            throw MySQLError(identifier: "float", reason: "Cannot decode Float from MySQLData: \(mysqlData).")
        }

        return int
    }
}

extension Double: MySQLDataConvertible { }
extension Float: MySQLDataConvertible { }

/// MARK: UUID

extension UUID: MySQLDataConvertible {
    /// See `MySQLDataConvertible.convertToMySQLData(format:)`
    public func convertToMySQLData() -> MySQLData {
        let binary = MySQLBinaryData(type: .MYSQL_TYPE_STRING, isUnsigned: false, storage: .string(convertToData()))
        return MySQLData(storage: .binary(binary))
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> UUID {
        guard let data = mysqlData.data() else {
            throw MySQLError(identifier: "uuid", reason: "Could not parse UUID from: \(mysqlData)")
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

private final class _DateComponentsWrapper {
    var value = DateComponents(
        calendar:  Calendar(identifier: .gregorian),
        timeZone: TimeZone(secondsFromGMT: 0)!
    )
}

private var _comps = ThreadSpecificVariable<_DateComponentsWrapper>()


extension Date {
    static func convertFromMySQLTime(_ time: MySQLTime) throws -> Date {
        let comps: _DateComponentsWrapper
        if let existing = _comps.currentValue {
            comps = existing
        } else {
            let new = _DateComponentsWrapper()
            _comps.currentValue = new
            comps = new
        }
        /// For some reason comps.nanosecond is `nil` on linux :(
        let nanosecond: Int
        #if os(macOS)
        nanosecond = numericCast(time.microsecond) * 1_000
        #else
        nanosecond = 0
        #endif
        
        comps.value.year = numericCast(time.year)
        comps.value.month = numericCast(time.month)
        comps.value.day = numericCast(time.day)
        comps.value.hour = numericCast(time.hour)
        comps.value.minute = numericCast(time.minute)
        comps.value.second = numericCast(time.second)
        comps.value.nanosecond = numericCast(time.microsecond) * 1_000
        
        guard let date = comps.value.date else {
            throw MySQLError(identifier: "date", reason: "Could not parse Date from: \(time)")
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
        
        let microsecond = UInt32(abs(timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 1_000_000))
        
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
    public func convertToMySQLData() -> MySQLData {
        let binary = MySQLBinaryData(type: .MYSQL_TYPE_TIMESTAMP, isUnsigned: false, storage: .time(convertToMySQLTime()))
        return MySQLData(storage: .binary(binary))
    }

    /// See `MySQLDataConvertible.convertFromMySQLData()`
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Date {
        let time: MySQLTime
        switch mysqlData.storage {
        case .binary(let binary):
            switch binary.storage {
            case .time(let _time): time = _time
            default: throw MySQLError(identifier: "timeBinary", reason: "Parsing MySQLTime from \(binary) is not supported.")
            }
        case .text: throw MySQLError(identifier: "timeText", reason: "Parsing MySQLTime from text is not supported.")
        }

        return try .convertFromMySQLTime(time)
    }
}
