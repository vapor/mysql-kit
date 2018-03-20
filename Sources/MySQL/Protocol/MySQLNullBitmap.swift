import Bits
import Debugging

/// 14.7.2.1 NULL-Bitmap
///
/// The binary protocol sends NULL values as bits inside a bitmap instead of a full byte as the ProtocolText::ResultsetRow does.
/// If many NULL values are sent, it is more efficient than the old way.
///
/// https://dev.mysql.com/doc/internals/en/null-bitmap.html
struct MySQLNullBitmap {
    /// This bitmap's static offset. This varies depending on which packet
    /// the bitmap is being used in.
    let offset: Int

    /// the raw bitmap bytes.
    var bytes: Bytes

    /// Creates a new `MySQLNullBitmap` from column count and an offset.
    private init(count: Int, offset: Int) {
        self.offset = offset
        self.bytes = Bytes(repeating: 0, count: (count + 7 + offset) / 8)
    }

    /// Creates a new `MySQLNullBitmap` from bytes and an offset.
    private init(bytes: Bytes, offset: Int) {
        self.offset = offset
        self.bytes = bytes
    }

    /// Sets the position to null.
    mutating func setNull(at pos: Int) {
        /// NULL-bitmap-byte = ((field-pos + offset) / 8)
        /// NULL-bitmap-bit  = ((field-pos + offset) % 8)
        let NULL_bitmap_byte = (pos + offset) / 8
        let NULL_bitmap_bit = (pos + offset) % 8

        bytes[NULL_bitmap_byte] |= 0b1 << NULL_bitmap_bit
    }

    /// Returns `true` if the bitmap is null at the supplied position.
    func isNull(at pos: Int) -> Bool {
        /// NULL-bitmap-byte = ((field-pos + offset) / 8)
        /// NULL-bitmap-bit  = ((field-pos + offset) % 8)
        let NULL_bitmap_byte = (pos + offset) / 8
        let NULL_bitmap_bit = (pos + offset) % 8

        let check = bytes[NULL_bitmap_byte] & (0b1 << NULL_bitmap_bit)
        return check > 0
    }

    /// Creates a new `MySQLNullBitmap` suitable for com statement execute packets.
    static func comExecuteBitmap(count: Int) -> MySQLNullBitmap {
        return .init(count: count, offset: 0)
    }

    /// Creates a new `MySQLNullBitmap` suitable for binary result set packets.
    static func binaryResultSetBitmap(bytes: Bytes) -> MySQLNullBitmap {
        return .init(bytes: bytes, offset: 2)
    }
}

extension ByteBuffer {
    /// Reads a `MySQLNullBitmap` for binary result sets from the `ByteBuffer`.
    mutating func requireResultSetNullBitmap(count: Int, source: @autoclosure () -> (SourceLocation)) throws -> MySQLNullBitmap {
        return try MySQLNullBitmap.binaryResultSetBitmap(
            bytes: requireBytes(length: (count + 7 + 2) / 8, source: source)
        )
    }
}

extension MySQLNullBitmap: CustomStringConvertible {
    /// See `CustomStringConvertible.description`
    var description: String {
        var desc: String = "0b"
        let tests: [Byte] = [
            0b1000_0000,
            0b0100_0000,
            0b0010_0000,
            0b0001_0000,
            0b0000_1000,
            0b0000_0100,
            0b0000_0010,
            0b0000_0001,
            ]
        for byte in bytes {
            if desc != "0b" {
                desc.append(" ")
            }
            for test in tests {
                if test == 0b0000_1000 {
                    desc.append("_")
                }
                if byte & test > 0 {
                    desc.append("1")
                } else {
                    desc.append("0")
                }
            }
        }
        return desc
    }
}
