import Bits
import Debugging

/// MARK: Assert

extension ByteBuffer {
    public mutating func requireInteger<T>(endianness: Endianness = .big, as type: T.Type = T.self, source: @autoclosure () -> (SourceLocation)) throws -> T where T: FixedWidthInteger {
        guard let int = readInteger(endianness: endianness, as: T.self) else {
            throw MySQLError(identifier: "integer", reason: "Could not parse \(T.self).", source: source())
        }
        return int
    }

    public mutating func requireNullTerminatedString(source: @autoclosure () -> (SourceLocation)) throws -> String {
        guard let string = readNullTerminatedString() else {
            throw MySQLError(identifier: "nullTerminatedString", reason: "Could not parse null terminated string.", source: source())
        }
        return string
    }

    public mutating func requireString(length: Int, source: @autoclosure () -> (SourceLocation)) throws -> String {
        guard let string = readString(length: length) else {
            throw MySQLError(identifier: "string", reason: "Could not parse \(length) character string.", source: source())
        }
        return string
    }

    public mutating func requireBytes(length: Int, source: @autoclosure () -> (SourceLocation)) throws -> [UInt8] {
        guard let bytes = readBytes(length: length) else {
            throw MySQLError(identifier: "bytes", reason: "Could not parse \(length) bytes.", source: source())
        }
        return bytes
    }

    public mutating func requireLengthEncodedInteger(source: @autoclosure () -> (SourceLocation)) throws -> UInt64 {
        guard let int = readLengthEncodedInteger() else {
            throw MySQLError(identifier: "lengthEncodedInt", reason: "Could not parse length encoded integer.", source: source())
        }
        return int
    }

    public mutating func requireLengthEncodedString(source: @autoclosure () -> (SourceLocation)) throws -> String {
        guard let string = readLengthEncodedString() else {
            throw MySQLError(identifier: "lengthEncodedString", reason: "Could not parse length encoded string.", source: source())
        }
        return string
    }
}

/// MARK: Null-terminated string

extension ByteBuffer {
    public mutating func write(nullTerminated string: String) {
        self.write(string: string)
        self.write(integer: Byte(0))
    }
}

/// MARK: Length Encoded Int

extension ByteBuffer {
    /// Returns packet length if there are enough readable bytes.
    mutating func checkPacketLength(source: @autoclosure () -> (SourceLocation)) throws -> Int32? {
        // erase sequence id so we can easily parse 4 byte integer
        set(integer: Byte(0), at: readerIndex + 3)
        guard let length = peekInteger(endianness: .little, as: Int32.self) else {
            return nil
        }
        if readableBytes >= length + 4 /* must be enough bytes to read length too */ {
            return try requireInteger(endianness: .little, source: source)
        } else {
            return nil
        }
    }

    func peekInteger<T>(endianness: Endianness = .big, as type: T.Type = T.self, skipping: Int = 0) -> T? where T: FixedWidthInteger {
        guard readableBytes >= MemoryLayout<T>.size + skipping else {
            return nil
        }
        return getInteger(at: readerIndex + skipping, endianness: endianness)
    }

    public mutating func readLengthEncodedString() -> String? {
        guard let size = readLengthEncodedInteger() else {
            return nil
        }

        if size == 0 {
            return ""
        }

        return readString(length: Int(size))
    }

    public mutating func readLengthEncodedInteger() -> UInt64? {
        guard let first: Byte = peekInteger() else {
            return nil
        }

        switch first {
        case 0xFC:
            guard let uint16 = readInteger(endianness: .little, as: UInt16.self) else {
                return nil
            }
            return numericCast(uint16) + 0xFC
        case 0xFD: fatalError("3-byte int support")
        case 0xFE:
            guard let uint64 = readInteger(endianness: .little, as: UInt64.self) else {
                return nil
            }
            return uint64 + 0xFE
        default:
            guard let byte = readInteger(endianness: .little, as: UInt8.self) else {
                return nil
            }
            return numericCast(byte)
        }
    }
}
