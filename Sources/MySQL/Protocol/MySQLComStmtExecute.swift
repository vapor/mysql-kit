import Bits

/// COM_STMT_EXECUTE asks the server to execute a prepared statement as identified by stmt-id.
///
/// It sends the values for the placeholders of the prepared statement (if it contained any) in Binary Protocol Value form.
/// The type of each parameter is made up of two bytes:
/// - the type as in Protocol::ColumnType
/// - a flag byte which has the highest bit set if the type is unsigned [80]
///
/// The num-params used for this packet has to match the num_params of the COM_STMT_PREPARE_OK of the corresponding prepared statement.
///
/// The server returns a COM_STMT_EXECUTE Response.
///
/// https://dev.mysql.com/doc/internals/en/com-stmt-execute.html#packet-COM_STMT_EXECUTE
struct MySQLComStmtExecute {
    /// stmt-id
    var statementID: UInt32

    /// flags
    var flags: Byte

    /// The values to bind
    var values: [MySQLBinaryData]

    /// Serializes the `MySQLComStmtExecute` into a buffer.
    func serialize(into buffer: inout ByteBuffer) {
        /// [17] COM_STMT_EXECUTE
        buffer.write(integer: Byte(0x17))
        buffer.write(integer: statementID, endianness: .little)
        buffer.write(integer: flags, endianness: .little)
        /// iteration-count
        /// The iteration-count is always 1.
        buffer.write(integer: Int32(0x01), endianness: .little)
        if values.count > 0 {
            /// NULL-bitmap, length: (num-params+7)/8
            var nullBitmap = Bytes(repeating: 0, count: (values.count + 7) / 8)

            for (i, value) in values.enumerated() {
                if value.storage == nil {
                    let byteOffset = i / 8
                    let bitOffset = i % 8

                    let bitEncoded: UInt8 = 0b00000001 << (7 - numericCast(bitOffset))
                    nullBitmap[byteOffset] |= bitEncoded
                }
            }
            buffer.write(bytes: nullBitmap)

            /// new-params-bound-flag
            buffer.write(integer: Byte(0x01))

            /// set value types
            for value in values {
                buffer.write(integer: value.type.raw, endianness: .little)
                /// a flag byte which has the highest bit set if the type is unsigned [80]
                if value.isUnsigned {
                    buffer.write(integer: Byte(0x80))
                } else {
                    buffer.write(integer: Byte(0x00))
                }
            }

            /// set values
            for value in values {
                if let data = value.storage {
                    switch data {
                    case .integer1(let int1): buffer.write(integer: int1, endianness: .little)
                    case .integer2(let int2): buffer.write(integer: int2, endianness: .little)
                    case .integer4(let int4): buffer.write(integer: int4, endianness: .little)
                    case .integer8(let int8): buffer.write(integer: int8, endianness: .little)
                    case .float4(let float4): fatalError("write float4 is not yet supported")
                    case .float8(let float8): fatalError("write float8 is not yet supported")
                    case .string(let data):
                        buffer.write(lengthEncoded: numericCast(data.count))
                        buffer.write(bytes: data)
                    }
                }
            }
        }
    }
}
