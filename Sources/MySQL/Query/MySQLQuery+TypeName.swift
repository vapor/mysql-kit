extension MySQLQuery {
    public enum TypeName {
        // MARK: Numeric
        
        /// A bit-value type. M indicates the number of bits per value, from 1 to 64.
        /// The default is 1 if M is omitted.
        case bit(Int?)
        
        /// A very small integer. The signed range is -128 to 127.
        /// The unsigned range is 0 to 255.
        case tinyint(Int?, unsigned: Bool, zerofill: Bool)
        
        /// These types are synonyms for TINYINT(1).
        /// A value of zero is considered false. Nonzero values are considered true:
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
        case char(Int?, MySQLCharacterSet?, MySQLCollate?)
        
        /// A variable-length string. M represents the maximum column length in characters. The range of M is 0 to 65,535.
        /// The effective maximum length of a VARCHAR is subject to the maximum row size (65,535 bytes, which is shared among all columns)
        /// and the character set used. For example, utf8 characters can require up to three bytes per character, so a VARCHAR column that
        /// uses the utf8 character set can be declared to be a maximum of 21,844 characters.
        case varchar(Int?, MySQLCharacterSet?, MySQLCollate?)
        
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
        case tinytext(MySQLCharacterSet?, MySQLCollate?)
        
        /// A BLOB column with a maximum length of 65,535 (216 − 1) bytes. Each BLOB value is stored using a 2-byte length prefix that indicates
        /// the number of bytes in the value. An optional length M can be given for this type. If this is done, MySQL creates the column as the
        /// smallest BLOB type large enough to hold values M bytes long.
        case blob(Int?)
        
        /// A TEXT column with a maximum length of 65,535 (216 − 1) characters. The effective maximum length is less if the value contains
        /// multibyte characters. Each TEXT value is stored using a 2-byte length prefix that indicates the number of bytes in the value.
        /// An optional length M can be given for this type. If this is done, MySQL creates the column as the smallest TEXT type large
        /// enough to hold values M characters long.
        case text(Int?, MySQLCharacterSet?, MySQLCollate?)
        
        /// A BLOB column with a maximum length of 16,777,215 (224 − 1) bytes. Each MEDIUMBLOB value is stored using a 3-byte length prefix that
        /// indicates the number of bytes in the value.
        case mediumblob
        
        /// A TEXT column with a maximum length of 16,777,215 (224 − 1) characters. The effective maximum length is less if the value contains
        /// multibyte characters. Each MEDIUMTEXT value is stored using a 3-byte length prefix that indicates the number of bytes in the value.
        case mediumtext(MySQLCharacterSet?, MySQLCollate?)
        
        /// A BLOB column with a maximum length of 4,294,967,295 or 4GB (232 − 1) bytes. The effective maximum length of LONGBLOB columns depends
        /// on the configured maximum packet size in the client/server protocol and available memory. Each LONGBLOB value is stored using a 4-byte
        // length prefix that indicates the number of bytes in the value.
        case longblob
        
        /// A TEXT column with a maximum length of 4,294,967,295 or 4GB (232 − 1) characters. The effective maximum length is less if the value
        /// contains multibyte characters. The effective maximum length of LONGTEXT columns also depends on the configured maximum packet size in
        /// the client/server protocol and available memory. Each LONGTEXT value is stored using a 4-byte length prefix that indicates the number
        /// of bytes in the value.
        case longtext(MySQLCharacterSet?, MySQLCollate?)
        
        /// An enumeration.
        
        /// A string object that can have only one value, chosen from the list of values 'value1', 'value2', ..., NULL or the special '' error value.
        /// ENUM values are represented internally as integers.
        /// An ENUM column can have a maximum of 65,535 distinct elements.
        /// The maximum supported length of an individual ENUM element is M <= 255 and (M x w) <= 1020, where M is the element literal length and
        /// w is the number of bytes required for the maximum-length character in the character set.
        case `enum`([String?], MySQLCharacterSet?, MySQLCollate?)
        
        /// A set. A string object that can have zero or more values, each of which must be chosen from the list of values 'value1', 'value2', ...
        /// SET values are represented internally as integers. A SET column can have a maximum of 64 distinct members.
        /// The maximum supported length of an individual SET element is M <= 255 and (M x w) <= 1020, where M is the element literal length and
        /// w is the number of bytes required for the maximum-length character in the character set.
        case set([String], MySQLCharacterSet?, MySQLCollate?)
    }
}

// FIXME: add collate
public struct MySQLCollate: CustomStringConvertible {
    
    public var description: String {
        return ""
    }
}

/// An optional fsp value in the range from 0 to 6 may be given to specify fractional seconds precision.
/// A value of 0 signifies that there is no fractional part. If omitted, the default precision is 0.
public struct MySQLFractionalSecondsPrecision: ExpressibleByIntegerLiteral {
    public let value: UInt8
    
    public init?(_ value: UInt8) {
        switch value {
        case 0...6: self.value = value
        default: return nil
        }
    }
    
    public init(integerLiteral value: UInt8) {
        guard let fsp = MySQLFractionalSecondsPrecision(value) else {
            fatalError("Invalid FSP value.")
        }
        self = fsp
    }
}

extension MySQLSerializer {
    func serialize(_ type: MySQLQuery.TypeName) -> String {
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
        
        func _string(_ name: String, _ m: Int? = nil, _ charset: MySQLCharacterSet? = nil, _ collate: MySQLCollate? = nil) -> String {
            var sql: [String] = []
            switch m {
            case .some(let m): sql.append(name + "(" + m.description + ")")
            case .none: sql.append(name)
            }
            if let charset = charset {
                sql.append(charset.description)
            }
            if let collate = collate {
                sql.append(collate.description)
            }
            return sql.joined(separator: " ")
        }
        
        switch type {
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
        }
    }
}
