extension MySQLQuery {
    public enum TypeName {
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
        
        // FIXME: dates
        
        case varchar(Int)
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
        case .varchar(let n): return "VARCHAR(" + n.description + ")"
        }
    }
}
