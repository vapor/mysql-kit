extension ByteBuffer {
    public mutating func assertReadInteger<T>(endianness: Endianness = .big, as: T.Type = T.self) -> T where T: FixedWidthInteger {
        precondition(readableBytes >= MemoryLayout<T>.size, "not enough readable bytes remaining")
        defer { moveReaderIndex(forwardBy: MemoryLayout<T>.size) }
        return getInteger(at: readerIndex, endianness: endianness)!
    }

    public mutating func assertReadNullTerminatedString() -> String {
        let string = readNullTerminatedString()
        assert(string != nil, "nil null terminated string")
        return string!
    }

    public mutating func assertReadString(length: Int) -> String {
        precondition(length >= 0, "length must not be negative")
        precondition(readableBytes >= length, "not enough readable bytes remaining")
        defer { moveReaderIndex(forwardBy: length) }
        return getString(at: readerIndex, length: length)! /* must work, enough readable bytes */
    }

    public mutating func assertReadBytes(length: Int) -> [UInt8] {
        precondition(length >= 0, "length must not be negative")
        precondition(readableBytes >= length, "not enough readable bytes remaining")
        defer { moveReaderIndex(forwardBy: length) }
        return getBytes(at: readerIndex, length: length)! /* must work, enough readable bytes */
    }
}
