import NIO

/// This structure is used to represent GEOMETRY data (Currently only Points).
public enum MySQLGeometry: Equatable {
    case point(x: Double, y: Double)

    fileprivate var wkbType: UInt32 {
        switch self {
        case .point: return 1
        }
    }

    fileprivate static let headerSize = 9
}

extension MySQLGeometry: CustomStringConvertible {
    /// See `CustomStringConvertible`.
    public var description: String {
        switch self {
        case .point(x: let x, y: let y):
            return "Point(\(x) \(y))"
        }
    }
}

extension MySQLGeometry {
    func convertToData() -> Data {
        switch self {
        case .point(let x, let y):
            let bufferSize = MySQLGeometry.headerSize + 16 // 2 `Double`s
            var buffer = ByteBufferAllocator().buffer(capacity: bufferSize)
            buffer.write(integer: UInt32(0)) // 4 byte filler
            buffer.write(integer: UInt8(1)) // set little endian byte order
            buffer.write(integer: wkbType, endianness: .little) // geometry type
            buffer.write(floatingPoint: x)
            buffer.write(floatingPoint: y)
            guard let data = buffer.getData(at: 0, length: bufferSize) else {
                fatalError("Could not create Data from Buffer.")
            }
            return data
        }
    }

    static func convertFromData(_ data: Data) throws -> MySQLGeometry {
        let count = data.count
        guard count >= headerSize else {
            throw MySQLError(identifier: "geometryType", reason: "Not enough data to read geometry type.")
        }
        var buffer = ByteBufferAllocator().buffer(capacity: count)
        buffer.write(bytes: data)

        _ = try buffer.requireInteger(endianness: .little, as: UInt32.self)
        guard try buffer.requireInteger(endianness: .little, as: UInt8.self) == 1 else {
            throw MySQLError(identifier: "endianness", reason: "Expected value of `1` for endianness.")
        }

        let wkbType: UInt32 = try buffer.requireInteger(endianness: .little)

        switch wkbType {
        case 1:
            return try .point(
                x: buffer.requireFloatingPoint(),
                y: buffer.requireFloatingPoint()
            )
        default:
            throw MySQLError(identifier: "geometryType", reason: "Only 'Point' geometry data type is supported.")
        }
    }
}

extension MySQLGeometry: MySQLDataTypeStaticRepresentable {
    /// See `MySQLDataTypeStaticRepresentable`.
    public static var mysqlDataType: MySQLDataType {
        return .geometry
    }
}

extension MySQLGeometry: MySQLDataConvertible {
    /// See `MySQLDataConvertible`.
    public func convertToMySQLData() -> MySQLData {
        let binary = MySQLBinaryData(
            type: .MYSQL_TYPE_GEOMETRY,
            isUnsigned: false,
            storage: .string(convertToData())
        )
        return MySQLData(storage: .binary(binary))
    }

    /// See `MySQLDataConvertible`.
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> MySQLGeometry {
        switch mysqlData.storage {
        case .binary(let binary):
            switch binary.storage {
            case .string(let data): return try .convertFromData(data)
            default: throw MySQLError(identifier: "pointBinary", reason: "Parsing MySQLGeometry from \(binary) is not supported.")
            }
        case .text: throw MySQLError(identifier: "pointText", reason: "Parsing MySQLGeometry from text is not supported.")
        }
    }
}
