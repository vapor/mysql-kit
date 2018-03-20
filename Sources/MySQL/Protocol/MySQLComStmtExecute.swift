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
    func serialize(into buffer: inout ByteBuffer) throws {
        /// [17] COM_STMT_EXECUTE
        buffer.write(integer: Byte(0x17))
        buffer.write(integer: statementID, endianness: .little)
        buffer.write(integer: flags, endianness: .little)
        /// iteration-count
        /// The iteration-count is always 1.
        buffer.write(integer: Int32(0x01), endianness: .little)
        if values.count > 0 {
            /// NULL-bitmap, length: (num-params+7)/8
            var nullBitmap = MySQLNullBitmap.comExecuteBitmap(count: values.count)

            for (i, value) in values.enumerated() {
                if value.storage == nil {
                    nullBitmap.setNull(at: i)
                }
            }
            buffer.write(bytes: nullBitmap.bytes)

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
                    case .uinteger1(let uint1): buffer.write(integer: uint1, endianness: .little)
                    case .uinteger2(let uint2): buffer.write(integer: uint2, endianness: .little)
                    case .uinteger4(let uint4): buffer.write(integer: uint4, endianness: .little)
                    case .uinteger8(let uint8): buffer.write(integer: uint8, endianness: .little)
                    case .float4(let float4): buffer.write(floatingPoint: float4)
                    case .float8(let float8): buffer.write(floatingPoint: float8)
                    case .string(let data):
                        /// larger than 2^24 not yet supported
                        guard data.count < 16_777_216 else {
                            throw MySQLError(identifier: "dataTooLarge", reason: "Data must be <= 16MB", source: .capture())
                        }
                        buffer.write(lengthEncoded: numericCast(data.count))
                        buffer.write(bytes: data)
                    case .time(let time):
                        buffer.write(integer: Byte(11), endianness: .little)
                        buffer.write(integer: time.year, endianness: .little)
                        buffer.write(integer: time.month, endianness: .little)
                        buffer.write(integer: time.day, endianness: .little)
                        buffer.write(integer: time.hour, endianness: .little)
                        buffer.write(integer: time.minute, endianness: .little)
                        buffer.write(integer: time.second, endianness: .little)
                        buffer.write(integer: time.microsecond, endianness: .little)
                    }
                }
            }
        }
    }
}
