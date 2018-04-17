import Bits

/// 14.1.4 Character Set
///
/// MySQL has a very flexible character set support as documented in Character Sets, Collations, Unicode.
/// https://dev.mysql.com/doc/internals/en/x-protocol-xplugin-implementation-of-the-x-protocol.html
///
/// A character set is defined in the protocol as a integer.
public struct MySQLCharacterSet: Equatable {
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

    /// Creates a new `MySQLCharacterSet`
    init?(string: String) {
        if string == "latin1_swedish_ci" {
            self.raw = 0x0008
        } else if string == "utf8_general_ci" {
              self.raw = 0x0021
        } else if string == "binary" {
            self.raw = 0x003f
        } else if string == "utf8mb4_unicode_ci" {
            self.raw = 0x00e0
        } else {
          return nil
        }
    }

    public static var latin1_swedish_ci: MySQLCharacterSet = 0x0008
    public static var utf8_general_ci: MySQLCharacterSet = 0x0021
    public static var binary: MySQLCharacterSet = 0x003f
    public static var utf8mb4_unicode_ci: MySQLCharacterSet = 0x00e0
}

extension MySQLCharacterSet: CustomStringConvertible {
    public var description: String {
        switch self {
        case .latin1_swedish_ci: return "latin1_swedish_ci"
        case .utf8_general_ci: return "utf8_general_ci"
        case .binary: return "binary"
        case .utf8mb4_unicode_ci: return "utf8mb4_unicode_ci"
        default: return "unknown \(self)"
        }
    }
}

extension MySQLCharacterSet: ExpressibleByIntegerLiteral {
    /// See `ExpressibleByIntegerLiteral.init(integerLiteral:)`
    public init(integerLiteral value: UInt16) {
        self.raw = value
    }
}
