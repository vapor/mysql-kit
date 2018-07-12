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
            let bufferSize = MySQLGeometry.headerSize + 2 * MemoryLayout<Double>.size
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
        buffer.withUnsafeMutableWritableBytes { (p) in
            p.copyBytes(from: data)
        }

        let _: UInt32 = try buffer.requireInteger()
        let _: UInt8 = try buffer.requireInteger()
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

extension MySQLGeometry: ReflectionDecodable {
    public static func reflectDecoded() throws -> (MySQLGeometry, MySQLGeometry) {
        return (.point(x: 0, y: 0), .point(x: 0, y: 1))
    }
}

extension MySQLGeometry: MySQLDataConvertible {
    public func convertToMySQLData() -> MySQLData {
        let binary = MySQLBinaryData(
            type: .MYSQL_TYPE_GEOMETRY,
            isUnsigned: false,
            storage: .string(convertToData())
        )
        return MySQLData(storage: .binary(binary))
    }

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
