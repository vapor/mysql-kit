/// MySQL table column data types.
public struct MySQLDataType: SQLDataType, Equatable {
    /// See `Equatable`.
    public static func == (lhs: MySQLDataType, rhs: MySQLDataType) -> Bool {
        // FIXME: more performant compare available once Swift has better equatable enum support
        var binds: [Encodable] = []
        return lhs.serialize(&binds) == rhs.serialize(&binds)
    }
    
    /// See `SQLDataType`.
    public static func dataType(appropriateFor type: Any.Type) -> MySQLDataType? {
        guard let type = type as? MySQLDataTypeStaticRepresentable.Type else {
            return .json
        }
        return type.mysqlDataType
    }
    
    // MARK: Numeric
    
    /// A bit-value type. M indicates the number of bits per value, from 1 to 64.
    /// The default is 1 if M is omitted.
    public static var bit: MySQLDataType {
        return .bit()
    }
    
    /// A bit-value type. M indicates the number of bits per value, from 1 to 64.
    /// The default is 1 if M is omitted.
    public static func bit(_ m: Int? = nil) -> MySQLDataType {
        return .init(.bit(m))
    }
    
    /// A very small integer. The signed range is -128 to 127.
    /// The unsigned range is 0 to 255.
    public static var tinyint: MySQLDataType {
        return .tinyint()
    }
    
    /// A very small integer. The signed range is -128 to 127.
    /// The unsigned range is 0 to 255.
    public static func tinyint(_ m: Int? = nil, unsigned: Bool = false, zerofill: Bool = false) -> MySQLDataType {
        return .init(.tinyint(m, unsigned: unsigned, zerofill: zerofill))
    }
    
    /// These types are synonyms for TINYINT(1).
    /// A value of zero is considered false. Nonzero values are considered true.
    public static var bool: MySQLDataType {
        return .init(.bool)
    }
    
    /// A small integer. The signed range is -32768 to 32767. The unsigned range is 0 to 65535.
    public static var smallint: MySQLDataType {
        return .smallint()
    }
    
    /// A small integer. The signed range is -32768 to 32767. The unsigned range is 0 to 65535.
    public static func smallint(_ m: Int? = nil, unsigned: Bool = false, zerofill: Bool = false) -> MySQLDataType {
        return .init(.smallint(m, unsigned: unsigned, zerofill: zerofill))
    }
    
    /// A medium-sized integer. The signed range is -8388608 to 8388607. The unsigned range is 0 to 16777215.
    public static var mediumint: MySQLDataType {
        return .mediumint()
    }
    
    /// A medium-sized integer. The signed range is -8388608 to 8388607. The unsigned range is 0 to 16777215.
    public static func mediumint(_ m: Int? = nil, unsigned: Bool = false, zerofill: Bool = false) -> MySQLDataType {
        return .init(.mediumint(m, unsigned: unsigned, zerofill: zerofill))
    }
    
    /// A normal-size integer. The signed range is -2147483648 to 2147483647. The unsigned range is 0 to 4294967295.
    public static var int: MySQLDataType {
        return .int()
    }
    
    /// A normal-size integer. The signed range is -2147483648 to 2147483647. The unsigned range is 0 to 4294967295.
    public static func int(_ m: Int? = nil, unsigned: Bool = false, zerofill: Bool = false) -> MySQLDataType {
        return .init(.int(m, unsigned: unsigned, zerofill: zerofill))
    }
    
    /// A large integer. The signed range is -9223372036854775808 to 9223372036854775807.
    /// The unsigned range is 0 to 18446744073709551615.
    public static var bigint: MySQLDataType {
        return .bigint()
    }
    
    /// A large integer. The signed range is -9223372036854775808 to 9223372036854775807.
    /// The unsigned range is 0 to 18446744073709551615.
    public static func bigint(_ m: Int? = nil, unsigned: Bool = false, zerofill: Bool = false) -> MySQLDataType {
        return .init(.bigint(m, unsigned: unsigned, zerofill: zerofill))
    }
    
    /// A packed “exact” fixed-point number. M is the total number of digits (the precision) and D is
    /// the number of digits after the decimal point (the scale).
    /// The decimal point and (for negative numbers) the - sign are not counted in M. If D is 0,
    /// values have no decimal point or fractional part. The maximum number of digits (M) for DECIMAL is 65.
    /// The maximum number of supported decimals (D) is 30. If D is omitted, the default is 0. If M is omitted,
    /// the default is 10.
    public static var decimal: MySQLDataType {
        return .decimal()
    }
    
    /// A packed “exact” fixed-point number. M is the total number of digits (the precision) and D is
    /// the number of digits after the decimal point (the scale).
    /// The decimal point and (for negative numbers) the - sign are not counted in M. If D is 0,
    /// values have no decimal point or fractional part. The maximum number of digits (M) for DECIMAL is 65.
    /// The maximum number of supported decimals (D) is 30. If D is omitted, the default is 0. If M is omitted,
    /// the default is 10.
    public static func decimal(_ md: (Int, Int?)? = nil, unsigned: Bool = false, zerofill: Bool = false) -> MySQLDataType {
        return .init(.decimal(md, unsigned: unsigned, zerofill: zerofill))
    }
    
    /// A small (single-precision) floating-point number. Permissible values are -3.402823466E+38 to -1.175494351E-38,
    /// 0, and 1.175494351E-38 to 3.402823466E+38. These are the theoretical limits, based on the IEEE standard.
    /// The actual range might be slightly smaller depending on your hardware or operating system.
    public static var float: MySQLDataType {
        return .float()
    }
    
    /// A small (single-precision) floating-point number. Permissible values are -3.402823466E+38 to -1.175494351E-38,
    /// 0, and 1.175494351E-38 to 3.402823466E+38. These are the theoretical limits, based on the IEEE standard.
    /// The actual range might be slightly smaller depending on your hardware or operating system.
    public static func float(_ md: (Int, Int)? = nil, unsigned: Bool = false, zerofill: Bool = false) -> MySQLDataType {
        return .init(.float(md, unsigned: unsigned, zerofill: zerofill))
    }
    
    /// A normal-size (double-precision) floating-point number. Permissible values are -1.7976931348623157E+308 to
    /// -2.2250738585072014E-308, 0, and 2.2250738585072014E-308 to 1.7976931348623157E+308.
    /// These are the theoretical limits, based on the IEEE standard. The actual range might be slightly smaller
    /// depending on your hardware or operating system.
    public static var double: MySQLDataType {
        return .double()
    }
    
    /// A normal-size (double-precision) floating-point number. Permissible values are -1.7976931348623157E+308 to
    /// -2.2250738585072014E-308, 0, and 2.2250738585072014E-308 to 1.7976931348623157E+308.
    /// These are the theoretical limits, based on the IEEE standard. The actual range might be slightly smaller
    /// depending on your hardware or operating system.
    public static func double(_ md: (Int, Int)? = nil, unsigned: Bool = false, zerofill: Bool = false) -> MySQLDataType {
        return .init(.double(md, unsigned: unsigned, zerofill: zerofill))
    }
    
    // MARK: Date and Time
    
    /// A date. The supported range is '1000-01-01' to '9999-12-31'. MySQL displays DATE values in 'YYYY-MM-DD' format,
    /// but permits assignment of values to DATE columns using either strings or numbers.
    public static var date: MySQLDataType {
        return .init(.date)
    }
    
    /// A date and time combination. The supported range is '1000-01-01 00:00:00.000000' to '9999-12-31 23:59:59.999999'.
    /// MySQL displays DATETIME values in 'YYYY-MM-DD HH:MM:SS[.fraction]' format, but permits assignment of values to DATETIME
    /// columns using either strings or numbers.
    public static var datetime: MySQLDataType {
        return .datetime()
    }
    
    /// A date and time combination. The supported range is '1000-01-01 00:00:00.000000' to '9999-12-31 23:59:59.999999'.
    /// MySQL displays DATETIME values in 'YYYY-MM-DD HH:MM:SS[.fraction]' format, but permits assignment of values to DATETIME
    /// columns using either strings or numbers.
    public static func datetime(_ fsp: MySQLFractionalSecondsPrecision? = nil) -> MySQLDataType {
        return .init(.datetime(fsp))
    }
    
    /// A timestamp. The range is '1970-01-01 00:00:01.000000' UTC to '2038-01-19 03:14:07.999999' UTC.
    /// TIMESTAMP values are stored as the number of seconds since the epoch ('1970-01-01 00:00:00' UTC).
    /// A TIMESTAMP cannot represent the value '1970-01-01 00:00:00' because that is equivalent to 0 seconds from the epoch and the
    /// value 0 is reserved for representing '0000-00-00 00:00:00', the “zero” TIMESTAMP value.
    public static var timestamp: MySQLDataType {
        return .timestamp()
    }
    
    /// A timestamp. The range is '1970-01-01 00:00:01.000000' UTC to '2038-01-19 03:14:07.999999' UTC.
    /// TIMESTAMP values are stored as the number of seconds since the epoch ('1970-01-01 00:00:00' UTC).
    /// A TIMESTAMP cannot represent the value '1970-01-01 00:00:00' because that is equivalent to 0 seconds from the epoch and the
    /// value 0 is reserved for representing '0000-00-00 00:00:00', the “zero” TIMESTAMP value.
    public static func timestamp(_ fsp: MySQLFractionalSecondsPrecision? = nil) -> MySQLDataType {
        return .init(.timestamp(fsp))
    }
    
    /// A time. The range is '-838:59:59.000000' to '838:59:59.000000'. MySQL displays TIME values in 'HH:MM:SS[.fraction]' format,
    /// but permits assignment of values to TIME columns using either strings or numbers.
    public static var time: MySQLDataType {
        return .time()
    }
    
    /// A time. The range is '-838:59:59.000000' to '838:59:59.000000'. MySQL displays TIME values in 'HH:MM:SS[.fraction]' format,
    /// but permits assignment of values to TIME columns using either strings or numbers.
    public static func time(_ fsp: MySQLFractionalSecondsPrecision? = nil) -> MySQLDataType {
        return .init(.time(fsp))
    }
    
    /// A year in four-digit format. MySQL displays YEAR values in YYYY format, but permits assignment of values to YEAR columns
    /// using either strings or numbers. Values display as 1901 to 2155, and 0000.
    public static var year: MySQLDataType {
        return .init(.year)
    }
    
    // MARK: String
    
    /// A fixed-length string that is always right-padded with spaces to the specified length when stored.
    /// M represents the column length in characters. The range of M is 0 to 255. If M is omitted, the length is 1.
    public static var char: MySQLDataType {
        return .char()
    }
    
    /// A fixed-length string that is always right-padded with spaces to the specified length when stored.
    /// M represents the column length in characters. The range of M is 0 to 255. If M is omitted, the length is 1.
    public static func char(_ m: Int? = nil, characterSet: MySQLCharacterSet? = nil, collate: MySQLCollation? = nil) -> MySQLDataType {
        return .init(.char(m, characterSet, collate))
    }
    
    /// A variable-length string. M represents the maximum column length in characters. The range of M is 0 to 65,535.
    /// The effective maximum length of a VARCHAR is subject to the maximum row size (65,535 bytes, which is shared among all columns)
    /// and the character set used. For example, utf8 characters can require up to three bytes per character, so a VARCHAR column that
    /// uses the utf8 character set can be declared to be a maximum of 21,844 characters.
    public static var varchar: MySQLDataType {
        return .varchar()
    }
    
    /// A variable-length string. M represents the maximum column length in characters. The range of M is 0 to 65,535.
    /// The effective maximum length of a VARCHAR is subject to the maximum row size (65,535 bytes, which is shared among all columns)
    /// and the character set used. For example, utf8 characters can require up to three bytes per character, so a VARCHAR column that
    /// uses the utf8 character set can be declared to be a maximum of 21,844 characters.
    public static func varchar(_ m: Int? = nil, characterSet: MySQLCharacterSet? = nil, collate: MySQLCollation? = nil) -> MySQLDataType {
        return .init(.varchar(m, characterSet, collate))
    }
    
    /// The BINARY type is similar to the CHAR type, but stores binary byte strings rather than nonbinary character strings.
    /// An optional length M represents the column length in bytes. If omitted, M defaults to 1.
    public static var binary: MySQLDataType {
        return .binary()
    }
    
    /// The BINARY type is similar to the CHAR type, but stores binary byte strings rather than nonbinary character strings.
    /// An optional length M represents the column length in bytes. If omitted, M defaults to 1.
    public static func binary(_ m: Int? = nil) -> MySQLDataType {
        return .init(.binary(m))
    }
    
    /// The VARBINARY type is similar to the VARCHAR type, but stores binary byte strings rather than nonbinary character strings.
    /// M represents the maximum column length in bytes.
    public static func varbinary(_ m: Int) -> MySQLDataType {
        return .init(.varbinary(m))
    }
    
    /// A BLOB column with a maximum length of 255 (28 − 1) bytes. Each TINYBLOB value is stored using a 1-byte length prefix that
    /// indicates the number of bytes in the value.
    public static var tinyblob: MySQLDataType {
        return .init(.tinyblob)
    }
    
    /// A TEXT column with a maximum length of 255 (28 − 1) characters. The effective maximum length is less if the value contains
    /// multibyte characters. Each TINYTEXT value is stored using a 1-byte length prefix that indicates the number of bytes in the value.
    public static var tinytext: MySQLDataType {
        return .tinytext()
    }
    
    /// A TEXT column with a maximum length of 255 (28 − 1) characters. The effective maximum length is less if the value contains
    /// multibyte characters. Each TINYTEXT value is stored using a 1-byte length prefix that indicates the number of bytes in the value.
    public static func tinytext(characterSet: MySQLCharacterSet? = nil, collate: MySQLCollation? = nil) -> MySQLDataType {
        return .init(.tinytext(characterSet, collate))
    }
    
    /// A BLOB column with a maximum length of 65,535 (216 − 1) bytes. Each BLOB value is stored using a 2-byte length prefix that indicates
    /// the number of bytes in the value. An optional length M can be given for this type. If this is done, MySQL creates the column as the
    /// smallest BLOB type large enough to hold values M bytes long.
    public static var blob: MySQLDataType {
        return .blob()
    }
    
    /// A BLOB column with a maximum length of 65,535 (216 − 1) bytes. Each BLOB value is stored using a 2-byte length prefix that indicates
    /// the number of bytes in the value. An optional length M can be given for this type. If this is done, MySQL creates the column as the
    /// smallest BLOB type large enough to hold values M bytes long.
    public static func blob(_ m: Int? = nil) -> MySQLDataType {
        return .init(.blob(m))
    }
    
    /// A TEXT column with a maximum length of 65,535 (216 − 1) characters. The effective maximum length is less if the value contains
    /// multibyte characters. Each TEXT value is stored using a 2-byte length prefix that indicates the number of bytes in the value.
    /// An optional length M can be given for this type. If this is done, MySQL creates the column as the smallest TEXT type large
    /// enough to hold values M characters long.
    public static var text: MySQLDataType {
        return .text()
    }
    
    /// A TEXT column with a maximum length of 65,535 (216 − 1) characters. The effective maximum length is less if the value contains
    /// multibyte characters. Each TEXT value is stored using a 2-byte length prefix that indicates the number of bytes in the value.
    /// An optional length M can be given for this type. If this is done, MySQL creates the column as the smallest TEXT type large
    /// enough to hold values M characters long.
    public static func text(_ m: Int? = nil, characterSet: MySQLCharacterSet? = nil, collate: MySQLCollation? = nil) -> MySQLDataType {
        return .init(.text(m, characterSet, collate))
    }
    
    /// A BLOB column with a maximum length of 16,777,215 (224 − 1) bytes. Each MEDIUMBLOB value is stored using a 3-byte length prefix that
    /// indicates the number of bytes in the value.
    public static var mediumblob: MySQLDataType {
        return .init(.mediumblob)
    }
    
    /// A TEXT column with a maximum length of 16,777,215 (224 − 1) characters. The effective maximum length is less if the value contains
    /// multibyte characters. Each MEDIUMTEXT value is stored using a 3-byte length prefix that indicates the number of bytes in the value.
    public static var mediumtext: MySQLDataType {
        return .mediumtext()
    }
    
    /// A TEXT column with a maximum length of 16,777,215 (224 − 1) characters. The effective maximum length is less if the value contains
    /// multibyte characters. Each MEDIUMTEXT value is stored using a 3-byte length prefix that indicates the number of bytes in the value.
    public static func mediumtext(characterSet: MySQLCharacterSet? = nil, collate: MySQLCollation? = nil) -> MySQLDataType {
        return .init(.mediumtext(characterSet, collate))
    }
    
    /// A BLOB column with a maximum length of 4,294,967,295 or 4GB (232 − 1) bytes. The effective maximum length of LONGBLOB columns depends
    /// on the configured maximum packet size in the client/server protocol and available memory. Each LONGBLOB value is stored using a 4-byte
    /// length prefix that indicates the number of bytes in the value.
    public static var longblob: MySQLDataType {
        return .init(.longblob)
    }
    
    /// A TEXT column with a maximum length of 4,294,967,295 or 4GB (232 − 1) characters. The effective maximum length is less if the value
    /// contains multibyte characters. The effective maximum length of LONGTEXT columns also depends on the configured maximum packet size in
    /// the client/server protocol and available memory. Each LONGTEXT value is stored using a 4-byte length prefix that indicates the number
    /// of bytes in the value.
    public static var longtext: MySQLDataType {
        return .longtext()
    }
    
    /// A TEXT column with a maximum length of 4,294,967,295 or 4GB (232 − 1) characters. The effective maximum length is less if the value
    /// contains multibyte characters. The effective maximum length of LONGTEXT columns also depends on the configured maximum packet size in
    /// the client/server protocol and available memory. Each LONGTEXT value is stored using a 4-byte length prefix that indicates the number
    /// of bytes in the value.
    public static func longtext(characterSet: MySQLCharacterSet? = nil, collate: MySQLCollation? = nil) -> MySQLDataType {
        return .init(.longtext(characterSet, collate))
    }
    
    /// MARK: Special
    
    /// A string object that can have only one value, chosen from the list of values 'value1', 'value2', ..., NULL or the special '' error value.
    /// ENUM values are represented internally as integers.
    /// An ENUM column can have a maximum of 65,535 distinct elements.
    /// The maximum supported length of an individual ENUM element is M <= 255 and (M x w) <= 1020, where M is the element literal length and
    /// w is the number of bytes required for the maximum-length character in the character set.
    public static func `enum`(_ cases: [String?], characterSet: MySQLCharacterSet? = nil, collate: MySQLCollation? = nil) -> MySQLDataType {
        return .init(.enum(cases, characterSet, collate))
    }
    
    /// A set. A string object that can have zero or more values, each of which must be chosen from the list of values 'value1', 'value2', ...
    /// SET values are represented internally as integers. A SET column can have a maximum of 64 distinct members.
    /// The maximum supported length of an individual SET element is M <= 255 and (M x w) <= 1020, where M is the element literal length and
    /// w is the number of bytes required for the maximum-length character in the character set.
    public static func set(_ cases: [String], characterSet: MySQLCharacterSet? = nil, collate: MySQLCollation? = nil) -> MySQLDataType {
        return .init(.set(cases, characterSet, collate))
    }
    
    /// MySQL supports a native JSON data type defined by RFC 7159 that enables efficient access to data in JSON
    /// (JavaScript Object Notation) documents.
    ///
    /// https://dev.mysql.com/doc/refman/8.0/en/json.html
    public static var json: MySQLDataType {
        return .init(.json)
    }
    
    let primitive: Primitive
    
    init(_ primitive: Primitive) {
        self.primitive = primitive
    }
    
    internal enum Primitive {
        /// A bit-value type. M indicates the number of bits per value, from 1 to 64.
        /// The default is 1 if M is omitted.
        case bit(Int?)
        
        /// A very small integer. The signed range is -128 to 127.
        /// The unsigned range is 0 to 255.
        case tinyint(Int?, unsigned: Bool, zerofill: Bool)
        
        /// These types are synonyms for TINYINT(1).
        /// A value of zero is considered false. Nonzero values are considered true.
        case bool
        
        /// A small integer. The signed range is -32768 to 32767. The unsigned range is 0 to 65535.
        case smallint(Int?, unsigned: Bool, zerofill: Bool)
        
        /// A medium-sized integer. The signed range is -8388608 to 8388607. The unsigned range is 0 to 16777215.
        case mediumint(Int?, unsigned: Bool, zerofill: Bool)
        
        /// A normal-size integer. The signed range is -2147483648 to 2147483647. The unsigned range is 0 to 4294967295.
        case int(Int?, unsigned: Bool, zerofill: Bool)
        
        /// A large integer. The signed range is -9223372036854775808 to 9223372036854775807.
        /// The unsigned range is 0 to 18446744073709551615.
        case bigint(Int?, unsigned: Bool, zerofill: Bool)
        
        /// A packed “exact” fixed-point number. M is the total number of digits (the precision) and D is
        /// the number of digits after the decimal point (the scale).
        /// The decimal point and (for negative numbers) the - sign are not counted in M. If D is 0,
        /// values have no decimal point or fractional part. The maximum number of digits (M) for DECIMAL is 65.
        /// The maximum number of supported decimals (D) is 30. If D is omitted, the default is 0. If M is omitted,
        // the default is 10.
        case decimal((Int, Int?)?, unsigned: Bool, zerofill: Bool)
        
        /// A small (single-precision) floating-point number. Permissible values are -3.402823466E+38 to -1.175494351E-38,
        /// 0, and 1.175494351E-38 to 3.402823466E+38. These are the theoretical limits, based on the IEEE standard.
        /// The actual range might be slightly smaller depending on your hardware or operating system.
        case float((Int, Int)?, unsigned: Bool, zerofill: Bool)
        
        /// A normal-size (double-precision) floating-point number. Permissible values are -1.7976931348623157E+308 to
        /// -2.2250738585072014E-308, 0, and 2.2250738585072014E-308 to 1.7976931348623157E+308.
        /// These are the theoretical limits, based on the IEEE standard. The actual range might be slightly smaller
        /// depending on your hardware or operating system.
        case double((Int, Int)?, unsigned: Bool, zerofill: Bool)
        
        // MARK: Date and Time
        
        /// A date. The supported range is '1000-01-01' to '9999-12-31'. MySQL displays DATE values in 'YYYY-MM-DD' format,
        /// but permits assignment of values to DATE columns using either strings or numbers.
        case date
        
        /// A date and time combination. The supported range is '1000-01-01 00:00:00.000000' to '9999-12-31 23:59:59.999999'.
        /// MySQL displays DATETIME values in 'YYYY-MM-DD HH:MM:SS[.fraction]' format, but permits assignment of values to DATETIME
        /// columns using either strings or numbers.
        case datetime(MySQLFractionalSecondsPrecision?)
        
        /// A timestamp. The range is '1970-01-01 00:00:01.000000' UTC to '2038-01-19 03:14:07.999999' UTC.
        /// TIMESTAMP values are stored as the number of seconds since the epoch ('1970-01-01 00:00:00' UTC).
        /// A TIMESTAMP cannot represent the value '1970-01-01 00:00:00' because that is equivalent to 0 seconds from the epoch and the
        /// value 0 is reserved for representing '0000-00-00 00:00:00', the “zero” TIMESTAMP value.
        case timestamp(MySQLFractionalSecondsPrecision?)
        
        /// A time. The range is '-838:59:59.000000' to '838:59:59.000000'. MySQL displays TIME values in 'HH:MM:SS[.fraction]' format,
        /// but permits assignment of values to TIME columns using either strings or numbers.
        case time(MySQLFractionalSecondsPrecision?)
        
        /// A year in four-digit format. MySQL displays YEAR values in YYYY format, but permits assignment of values to YEAR columns
        /// using either strings or numbers. Values display as 1901 to 2155, and 0000.
        case year
        
        // MARK: String
        
        /// A fixed-length string that is always right-padded with spaces to the specified length when stored.
        /// M represents the column length in characters. The range of M is 0 to 255. If M is omitted, the length is 1.
        case char(Int?, MySQLCharacterSet?, MySQLCollation?)
        
        /// A variable-length string. M represents the maximum column length in characters. The range of M is 0 to 65,535.
        /// The effective maximum length of a VARCHAR is subject to the maximum row size (65,535 bytes, which is shared among all columns)
        /// and the character set used. For example, utf8 characters can require up to three bytes per character, so a VARCHAR column that
        /// uses the utf8 character set can be declared to be a maximum of 21,844 characters.
        case varchar(Int?, MySQLCharacterSet?, MySQLCollation?)
        
        /// The BINARY type is similar to the CHAR type, but stores binary byte strings rather than nonbinary character strings.
        /// An optional length M represents the column length in bytes. If omitted, M defaults to 1.
        case binary(Int?)
        
        /// The VARBINARY type is similar to the VARCHAR type, but stores binary byte strings rather than nonbinary character strings.
        /// M represents the maximum column length in bytes.
        case varbinary(Int)
        
        /// A BLOB column with a maximum length of 255 (28 − 1) bytes. Each TINYBLOB value is stored using a 1-byte length prefix that
        /// indicates the number of bytes in the value.
        case tinyblob
        
        /// A TEXT column with a maximum length of 255 (28 − 1) characters. The effective maximum length is less if the value contains
        /// multibyte characters. Each TINYTEXT value is stored using a 1-byte length prefix that indicates the number of bytes in the value.
        case tinytext(MySQLCharacterSet?, MySQLCollation?)
        
        /// A BLOB column with a maximum length of 65,535 (216 − 1) bytes. Each BLOB value is stored using a 2-byte length prefix that indicates
        /// the number of bytes in the value. An optional length M can be given for this type. If this is done, MySQL creates the column as the
        /// smallest BLOB type large enough to hold values M bytes long.
        case blob(Int?)
        
        /// A TEXT column with a maximum length of 65,535 (216 − 1) characters. The effective maximum length is less if the value contains
        /// multibyte characters. Each TEXT value is stored using a 2-byte length prefix that indicates the number of bytes in the value.
        /// An optional length M can be given for this type. If this is done, MySQL creates the column as the smallest TEXT type large
        /// enough to hold values M characters long.
        case text(Int?, MySQLCharacterSet?, MySQLCollation?)
        
        /// A BLOB column with a maximum length of 16,777,215 (224 − 1) bytes. Each MEDIUMBLOB value is stored using a 3-byte length prefix that
        /// indicates the number of bytes in the value.
        case mediumblob
        
        /// A TEXT column with a maximum length of 16,777,215 (224 − 1) characters. The effective maximum length is less if the value contains
        /// multibyte characters. Each MEDIUMTEXT value is stored using a 3-byte length prefix that indicates the number of bytes in the value.
        case mediumtext(MySQLCharacterSet?, MySQLCollation?)
        
        /// A BLOB column with a maximum length of 4,294,967,295 or 4GB (232 − 1) bytes. The effective maximum length of LONGBLOB columns depends
        /// on the configured maximum packet size in the client/server protocol and available memory. Each LONGBLOB value is stored using a 4-byte
        // length prefix that indicates the number of bytes in the value.
        case longblob
        
        /// A TEXT column with a maximum length of 4,294,967,295 or 4GB (232 − 1) characters. The effective maximum length is less if the value
        /// contains multibyte characters. The effective maximum length of LONGTEXT columns also depends on the configured maximum packet size in
        /// the client/server protocol and available memory. Each LONGTEXT value is stored using a 4-byte length prefix that indicates the number
        /// of bytes in the value.
        case longtext(MySQLCharacterSet?, MySQLCollation?)
        
        /// MARK: Special
        
        /// A string object that can have only one value, chosen from the list of values 'value1', 'value2', ..., NULL or the special '' error value.
        /// ENUM values are represented internally as integers.
        /// An ENUM column can have a maximum of 65,535 distinct elements.
        /// The maximum supported length of an individual ENUM element is M <= 255 and (M x w) <= 1020, where M is the element literal length and
        /// w is the number of bytes required for the maximum-length character in the character set.
        case `enum`([String?], MySQLCharacterSet?, MySQLCollation?)
        
        /// A set. A string object that can have zero or more values, each of which must be chosen from the list of values 'value1', 'value2', ...
        /// SET values are represented internally as integers. A SET column can have a maximum of 64 distinct members.
        /// The maximum supported length of an individual SET element is M <= 255 and (M x w) <= 1020, where M is the element literal length and
        /// w is the number of bytes required for the maximum-length character in the character set.
        case set([String], MySQLCharacterSet?, MySQLCollation?)
        
        /// MySQL supports a native JSON data type defined by RFC 7159 that enables efficient access to data in JSON
        /// (JavaScript Object Notation) documents.
        ///
        /// https://dev.mysql.com/doc/refman/8.0/en/json.html
        case json
    }
    
    /// See `SQLSerializable`.
    public func serialize(_ binds: inout [Encodable]) -> String {
        func _int(_ name: String, _ m: Int?, _ unsigned: Bool = false, _ zerofill: Bool = false) -> String {
            var sql: [String] = []
            switch m {
            case .some(let m): sql.append(name + "(" + m.description + ")")
            case .none: sql.append(name)
            }
            if unsigned {
                sql.append("UNSIGNED")
            }
            if zerofill {
                sql.append("ZEROFILL")
            }
            return sql.joined(separator: " ")
        }
        
        func _float(_ name: String, _ md: (Int, Int)?, _ unsigned: Bool = false, _ zerofill: Bool = false) -> String {
            var sql: [String] = []
            switch md {
            case .some((let m, let d)):
                sql.append(name + "(" + m.description + "," + d.description + ")")
            case .none: sql.append(name)
            }
            if unsigned {
                sql.append("UNSIGNED")
            }
            if zerofill {
                sql.append("ZEROFILL")
            }
            return sql.joined(separator: " ")
        }
        func _date(_ name: String, _ fsp: MySQLFractionalSecondsPrecision?) -> String {
            switch fsp {
            case .some(let fsp): return name + "(" + fsp.value.description + ")"
            case .none: return name
            }
        }
        
        func _string(_ name: String, _ m: Int? = nil, _ charset: MySQLCharacterSet? = nil, _ collate: MySQLCollation? = nil) -> String {
            var sql: [String] = []
            switch m {
            case .some(let m): sql.append(name + "(" + m.description + ")")
            case .none: sql.append(name)
            }
            if let charset = charset {
                sql.append("CHARACTER SET")
                sql.append(charset.description)
            }
            if let collate = collate {
                sql.append("COLLATE")
                sql.append(collate.description)
            }
            return sql.joined(separator: " ")
        }
        
        switch primitive {
        case .bit(let m): return _int("BIT", m)
        case .tinyint(let m, let u, let z): return _int("TINYINT", m, u, z)
        case .bool: return "BOOL"
        case .smallint(let m, let u, let z): return _int("SMALLINT", m, u, z)
        case .mediumint(let m, let u, let z): return _int("MEDIUMINT", m, u, z)
        case .int(let m, let u, let z): return _int("INT", m, u, z)
        case .bigint(let m, let u, let z): return _int("BIGINT", m, u, z)
        case .decimal(let md, let unsigned, let zerofill):
            /// d is optional, so we can't re-use the float sql generation
            var sql: [String] = []
            switch md {
            case .some((let m, let d)):
                switch d {
                case .some(let d):
                    sql.append("DECIMAL(" + m.description + "," + d.description + ")")
                case .none:
                    sql.append("DECIMAL(" + m.description + ")")
                }
            case .none: sql.append("DECIMAL")
            }
            if unsigned {
                sql.append("UNSIGNED")
            }
            if zerofill {
                sql.append("ZEROFILL")
            }
            return sql.joined(separator: " ")
        case .float(let md, let u, let z): return _float("FLOAT", md, u, z)
        case .double(let md, let u, let z): return _float("DOUBLE", md, u, z)
        case .date: return "DATE"
        case .datetime(let fsp): return _date("DATETIME", fsp)
        case .timestamp(let fsp): return _date("TIMESTAMP", fsp)
        case .time(let fsp): return _date("TIME", fsp)
        case .year: return "YEAR(4)"
        case .char(let m, let ch, let c): return _string("CHAR", m, ch, c)
        case .varchar(let m, let ch, let c): return _string("VARCHAR", m, ch, c)
        case .binary(let m): return _string("BINARY", m)
        case .varbinary(let m): return _string("VARBINARY", m)
        case .tinyblob: return "TINYBLOB"
        case .tinytext(let ch, let c): return _string("TINYTEXT", nil, ch, c)
        case .blob(let m): return _string("BLOB", m)
        case .text(let m, let ch, let c): return _string("TEXT", m, ch, c)
        case .mediumblob: return "MEDIUMBLOB"
        case .mediumtext(let ch, let c): return _string("MEDIUMTEXT", nil, ch, c)
        case .longblob: return "LONGBLOB"
        case .longtext(let ch, let c): return _string("LONGTEXT", nil, ch, c)
        case .enum(let cases, let charset, let collate):
            var sql: [String] = []
            sql.append("ENUM(" + cases.map {
                switch $0 {
                case .some(let some): return "'" + some + "'"
                case .none: return "NULL"
                }
            }.joined(separator: ", ") + ")")
            if let charset = charset {
                sql.append(charset.description)
            }
            if let collate = collate {
                sql.append(collate.description)
            }
            return sql.joined(separator: " ")
        case .set(let values, let charset, let collate):
            var sql: [String] = []
            sql.append("SET(" + values.map { "'" + $0 + "'" }.joined(separator: ", ") + ")")
            if let charset = charset {
                sql.append(charset.description)
            }
            if let collate = collate {
                sql.append(collate.description)
            }
            return sql.joined(separator: " ")
        case .json: return "JSON"
        }
    }
}
