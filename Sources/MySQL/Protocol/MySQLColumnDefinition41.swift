import Bits

/// These don't seem to be documented anywhere.
struct MySQLColumnFlags: MySQLFlags {
    /// The raw status value.
    public var raw: UInt16

    /// Create a new `MySQLStatusFlags` from the raw value.
    public init(raw: UInt16) {
        self.raw = raw
    }

    /// This column is unsigned.
    public static var COLUMN_UNSIGNED: MySQLColumnFlags = 0b000_0000_0010_0000

    /// This column is the primary key.
    public static var PRIMARY_KEY: MySQLColumnFlags = 0b000_0000_0000_0010

    /// This column is not null.
    public static var COLUMN_NOT_NULL: MySQLColumnFlags = 0b000_0000_0000_0001
}

/// Protocol::ColumnDefinition41
///
/// Column Definition
/// if CLIENT_PROTOCOL_41 is set Protocol::ColumnDefinition41 is used, Protocol::ColumnDefinition320 otherwise
///
/// https://dev.mysql.com/doc/internals/en/com-query-response.html#packet-Protocol::ColumnDefinition
struct MySQLColumnDefinition41 {
    /// catalog (lenenc_str) -- catalog (always "def")
    var catalog: String

    /// schema (lenenc_str) -- schema-name
    var schema: String

    /// table (lenenc_str) -- virtual table-name
    var table: String

    /// org_table (lenenc_str) -- physical table-name
    var orgTable: String

    /// name (lenenc_str) -- virtual column name
    var name: String

    /// org_name (lenenc_str) -- physical column name
    var orgName: String

    /// character_set (2) -- is the column character set and is defined in Protocol::CharacterSet.
    var characterSet: MySQLCharacterSet

    /// column_length (4) -- maximum length of the field
    var columnLength: UInt32

    /// column_type (1) -- type of the column as defined in Column Type
    var columnType: MySQLDataType

    /// flags (2) -- flags
    var flags: MySQLColumnFlags

    /// decimals (1) -- max shown decimal digits
    /// - 0x00 for integers and static strings
    /// - 0x1f for dynamic strings, double, float
    /// - 0x00 to 0x51 for decimals
    /// note: decimals and column_length can be used for text-output formatting.
    var decimals: Byte

    /// Parses a `MySQLColumnDefinition41` from the `ByteBuffer`.
    init(bytes: inout ByteBuffer) throws {
        catalog = try bytes.requireLengthEncodedString(source: .capture())
        schema = try bytes.requireLengthEncodedString(source: .capture())
        table = try bytes.requireLengthEncodedString(source: .capture())
        orgTable = try bytes.requireLengthEncodedString(source: .capture())
        name = try bytes.requireLengthEncodedString(source: .capture())
        orgName = try bytes.requireLengthEncodedString(source: .capture())
        /// next_length (lenenc_int) -- length of the following fields (always 0x0c)
        let fixedLength = try bytes.requireLengthEncodedInteger(source: .capture())
        assert(fixedLength == 0x0C, "invalid fixed length: \(fixedLength)")
        characterSet = try .init(raw: bytes.requireInteger(endianness: .little, source: .capture()))
        columnLength = try bytes.requireInteger(endianness: .little, source: .capture())
        columnType = try .init(raw: bytes.requireInteger(endianness: .little, source: .capture()))
        flags = try .init(raw: bytes.requireInteger(endianness: .little, source: .capture()))
        decimals = try bytes.requireInteger(endianness: .little, source: .capture())
        /// 2              filler [00] [00]
        let filler = try bytes.requireInteger(endianness: .little, as: UInt16.self, source: .capture())
        assert(filler == 0x0000)

        /// FIXME: check if `if command was COM_FIELD_LIST {` for default values
    }
}
