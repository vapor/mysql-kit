import Bits

/// 14.1.4 Character Set
///
/// MySQL has a very flexible character set support as documented in Character Sets, Collations, Unicode.
///
/// A character set is defined in the protocol as a integer.
struct MySQLCharacterSet: Equatable {
    /// charset_nr (2) -- number of the character set and collation
    var raw: UInt16

    /// Creates a new `MySQLCharacterSet`
    init(raw: UInt16) {
        self.raw = raw
    }

    /// Creates a new `MySQLCharacterSet`
    init(byte: Byte) {
        self.raw = numericCast(byte)
    }

    static var latin1_swedish_ci: MySQLCharacterSet = 0x0008
    static var utf8_general_ci: MySQLCharacterSet = 0x0021
    static var binary: MySQLCharacterSet = 0x003f
}

extension MySQLCharacterSet: CustomStringConvertible {
    var description: String {
        switch self {
        case .latin1_swedish_ci: return "latin1_swedish_ci"
        case .utf8_general_ci: return "utf8_general_ci"
        case .binary: return "binary"
        default: return "unknown \(self.raw)"
        }
    }
}

extension MySQLCharacterSet: ExpressibleByIntegerLiteral {
    /// See `ExpressibleByIntegerLiteral.init(integerLiteral:)`
    init(integerLiteral value: UInt16) {
        self.raw = value
    }
}
