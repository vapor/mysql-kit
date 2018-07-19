/// The capability flags are used by the client and server to indicate which features they support and want to use.
///
/// https://dev.mysql.com/doc/internals/en/capability-flags.html#packet-Protocol::CapabilityFlags
public struct MySQLCapabilities: OptionSet {
    /// The raw capabilities value.
    public var rawValue: UInt64

    /// MySQL specific flags
    internal var general: UInt32 {
        get { return UInt32(rawValue & 0xFFFFFFFF) }
    }

    /// MariaDB Initial Handshake Packet specific flags
    /// https://mariadb.com/kb/en/library/1-connecting-connecting/
    internal var mariaDBSpecific: UInt32 {
        get { return UInt32(rawValue >> 32) }
        set { rawValue |= UInt64(newValue) << 32 }
    }

    /// Create a new `MySQLCapabilityFlags` from the upper and lower values.
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
    
    /// Create a new `MySQLCapabilities` from the upper and lower values.
    init(upper: UInt16? = nil, lower: UInt16) {
        var raw: UInt64 = 0
        if let upper = upper {
            raw = numericCast(lower)
            raw |= numericCast(upper) << 16
        } else {
            raw = numericCast(lower)
        }
        self.init(rawValue: raw)
    }
    
    /// Use the improved version of Old Password Authentication.
    /// note: Assumed to be set since 4.1.1.
    public static let CLIENT_LONG_PASSWORD = MySQLCapabilities(rawValue: 0x00000001)
    
    /// Send found rows instead of affected rows in EOF_Packet.
    public static let CLIENT_FOUND_ROWS = MySQLCapabilities(rawValue: 0x00000002)
    
    /// Longer flags in Protocol::ColumnDefinition320.
    /// Server: Supports longer flags.
    /// Client: Expects longer flags.
    public static let CLIENT_LONG_FLAG = MySQLCapabilities(rawValue: 0x00000004)
    
    /// Database (schema) name can be specified on connect in Handshake Response Packet.
    /// Server: Supports schema-name in Handshake Response Packet.
    /// Client: Handshake Response Packet contains a schema-name.
    public static let CLIENT_CONNECT_WITH_DB = MySQLCapabilities(rawValue: 0x00000008)
    
    /// Server: Do not permit database.table.column.
    public static let CLIENT_NO_SCHEMA = MySQLCapabilities(rawValue: 0x00000010)
    
    /// Compression protocol supported.
    /// Server: Supports compression.
    /// Client: Switches to Compression compressed protocol after successful authentication.
    public static let CLIENT_COMPRESS = MySQLCapabilities(rawValue: 0x00000020)
    
    /// Special handling of ODBC behavior.
    /// note: No special behavior since 3.22.
    public static let CLIENT_ODBC = MySQLCapabilities(rawValue: 0x00000040)
    
    /// Can use LOAD DATA LOCAL.
    /// Server: Enables the LOCAL INFILE request of LOAD DATA|XML.
    /// Client: Will handle LOCAL INFILE request.
    public static let CLIENT_LOCAL_FILES = MySQLCapabilities(rawValue: 0x00000080)
    
    /// Server: Parser can ignore spaces before '('.
    /// Client: Let the parser ignore spaces before '('.
    public static let CLIENT_IGNORE_SPACE = MySQLCapabilities(rawValue: 0x00000100)
    
    /// Server: Supports the 4.1 protocol.
    /// Client: Uses the 4.1 protocol.
    /// note: this value was CLIENT_CHANGE_USER in 3.22, unused in 4.0
    public static let CLIENT_PROTOCOL_41 = MySQLCapabilities(rawValue: 0x00000200)
    
    /// wait_timeout versus wait_interactive_timeout.
    /// Server: Supports interactive and noninteractive clients.
    /// Client: Client is interactive.
    /// See mysql_real_connect()
    public static let CLIENT_INTERACTIVE = MySQLCapabilities(rawValue: 0x00000400)
    
    /// Server: Supports SSL.
    /// Client: Switch to SSL after sending the capability-flags.
    public static let CLIENT_SSL = MySQLCapabilities(rawValue: 0x00000800)
    
    /// Client: Do not issue SIGPIPE if network failures occur (libmysqlclient only).
    /// See mysql_real_connect()
    public static let CLIENT_IGNORE_SIGPIPE = MySQLCapabilities(rawValue: 0x00001000)
    
    /// Server: Can send status flags in EOF_Packet.
    /// Client: Expects status flags in EOF_Packet.
    /// note: This flag is optional in 3.23, but always set by the server since 4.0.
    public static let CLIENT_TRANSACTIONS = MySQLCapabilities(rawValue: 0x00002000)
    
    /// Unused.
    /// note: Was named CLIENT_PROTOCOL_41 in 4.1.0.
    public static let CLIENT_RESERVED = MySQLCapabilities(rawValue: 0x00004000)
    
    /// Server: Supports Authentication::Native41.
    /// Client: Supports Authentication::Native41.
    public static let CLIENT_SECURE_CONNECTION = MySQLCapabilities(rawValue: 0x00008000)
    
    /// Server: Can handle multiple statements per COM_QUERY and COM_STMT_PREPARE.
    /// Client: May send multiple statements per COM_QUERY and COM_STMT_PREPARE.
    /// note: Was named CLIENT_MULTI_QUERIES in 4.1.0, renamed later.
    /// requires: CLIENT_PROTOCOL_41
    public static let CLIENT_MULTI_STATEMENTS = MySQLCapabilities(rawValue: 0x00010000)
    
    /// Server: Can send multiple resultsets for COM_QUERY.
    /// Client: Can handle multiple resultsets for COM_QUERY.
    /// requires: CLIENT_PROTOCOL_41
    public static let CLIENT_MULTI_RESULTS = MySQLCapabilities(rawValue: 0x00020000)
    
    /// Server: Can send multiple resultsets for COM_STMT_EXECUTE.
    /// Client: Can handle multiple resultsets for COM_STMT_EXECUTE.
    /// requires: CLIENT_PROTOCOL_41
    public static let CLIENT_PS_MULTI_RESULTS = MySQLCapabilities(rawValue: 0x00040000)
    
    /// Server: Sends extra data in Initial Handshake Packet and supports the pluggable authentication protocol.
    /// Client: Supports authentication plugins.
    /// Requires: CLIENT_PROTOCOL_41
    public static let CLIENT_PLUGIN_AUTH = MySQLCapabilities(rawValue: 0x00080000)
    
    /// Server: Permits connection attributes in Protocol::HandshakeResponse41.
    /// Client: Sends connection attributes in Protocol::HandshakeResponse41.
    public static let CLIENT_CONNECT_ATTRS = MySQLCapabilities(rawValue: 0x00100000)
    
    /// Server: Understands length-encoded integer for auth response data in Protocol::HandshakeResponse41.
    /// Client: Length of auth response data in Protocol::HandshakeResponse41 is a length-encoded integer.
    /// note: The flag was introduced in 5.6.6, but had the wrong value.
    public static let CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA = MySQLCapabilities(rawValue: 0x00200000)
    
    /// Server: Announces support for expired password extension.
    /// Client: Can handle expired passwords.
    /// https://dev.mysql.com/doc/internals/en/cs-sect-expired-password.html
    public static let CLIENT_CAN_HANDLE_EXPIRED_PASSWORDS = MySQLCapabilities(rawValue: 0x00400000)
    
    /// Server: Can set SERVER_SESSION_STATE_CHANGED in the Status Flags and send session-state change data after a OK packet.
    /// Client: Expects the server to send sesson-state changes after a OK packet.
    public static let CLIENT_SESSION_TRACK = MySQLCapabilities(rawValue: 0x00800000)
    
    /// Server: Can send OK after a Text Resultset.
    /// Client: Expects an OK (instead of EOF) after the resultset rows of a Text Resultset.
    /// To support CLIENT_SESSION_TRACK, additional information must be sent after all successful commands.
    /// Although the OK packet is extensible, the EOF packet is not due to the overlap of its bytes with the content of the Text Resultset Row.
    /// Therefore, the EOF packet in the Text Resultset is replaced with an OK packet. EOF packets are deprecated as of MySQL 5.7.5.
    public static let CLIENT_DEPRECATE_EOF = MySQLCapabilities(rawValue: 0x01000000)
  
    /// See: [MariaDB Initial Handshake Packet specific flags](https://mariadb.com/kb/en/library/1-connecting-connecting/)

    /// Client support progress indicator (since 10.2).
    public static let MARIADB_CLIENT_PROGRESS = MySQLCapabilities(rawValue: 0x0100000000) // 1 << 32

    /// Permit COM_MULTI protocol.
    public static let MARIADB_CLIENT_COM_MULTI = MySQLCapabilities(rawValue: 0x0200000000) // 1 << 33

    /// Permit bulk insert.
    public static let MARIADB_CLIENT_STMT_BULK_OPERATIONS = MySQLCapabilities(rawValue: 0x0400000000) // 1 << 34
    
    /// Default capabilities.
    ///
    /// - CLIENT_PROTOCOL_41,
    /// - CLIENT_PLUGIN_AUTH,
    /// - CLIENT_SECURE_CONNECTION,
    /// - CLIENT_CONNECT_WITH_DB,
    /// - CLIENT_DEPRECATE_EOF
    public static let `default`: MySQLCapabilities = [
        .CLIENT_PROTOCOL_41,
        .CLIENT_PLUGIN_AUTH,
        .CLIENT_SECURE_CONNECTION,
        .CLIENT_CONNECT_WITH_DB,
        .CLIENT_DEPRECATE_EOF
    ]
}

extension MySQLCapabilities: CustomStringConvertible {
    /// All capabilities.
    public static let all: [String: MySQLCapabilities] = [
        "CLIENT_LONG_PASSWORD": CLIENT_LONG_PASSWORD,
        "CLIENT_FOUND_ROWS": CLIENT_FOUND_ROWS,
        "CLIENT_LONG_FLAG": CLIENT_LONG_FLAG,
        "CLIENT_CONNECT_WITH_DB": CLIENT_CONNECT_WITH_DB,
        "CLIENT_NO_SCHEMA": CLIENT_NO_SCHEMA,
        "CLIENT_COMPRESS": CLIENT_COMPRESS,
        "CLIENT_ODBC": CLIENT_ODBC,
        "CLIENT_LOCAL_FILES": CLIENT_LOCAL_FILES,
        "CLIENT_IGNORE_SPACE": CLIENT_IGNORE_SPACE,
        "CLIENT_PROTOCOL_41": CLIENT_PROTOCOL_41,
        "CLIENT_INTERACTIVE": CLIENT_INTERACTIVE,
        "CLIENT_SSL": CLIENT_SSL,
        "CLIENT_IGNORE_SIGPIPE": CLIENT_IGNORE_SIGPIPE,
        "CLIENT_TRANSACTIONS": CLIENT_TRANSACTIONS,
        "CLIENT_RESERVED": CLIENT_RESERVED,
        "CLIENT_SECURE_CONNECTION": CLIENT_SECURE_CONNECTION,
        "CLIENT_MULTI_STATEMENTS": CLIENT_MULTI_STATEMENTS,
        "CLIENT_MULTI_RESULTS": CLIENT_MULTI_RESULTS,
        "CLIENT_PS_MULTI_RESULTS": CLIENT_PS_MULTI_RESULTS,
        "CLIENT_PLUGIN_AUTH": CLIENT_PLUGIN_AUTH,
        "CLIENT_CONNECT_ATTRS": CLIENT_CONNECT_ATTRS,
        "CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA": CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA,
        "CLIENT_CAN_HANDLE_EXPIRED_PASSWORDS": CLIENT_CAN_HANDLE_EXPIRED_PASSWORDS,
        "CLIENT_SESSION_TRACK": CLIENT_SESSION_TRACK,
        "CLIENT_DEPRECATE_EOF": CLIENT_DEPRECATE_EOF,
    ]
    
    /// See `CustomStringConvertible`.
    public var description: String {
        var desc: [String] = []
        for (name, flag) in MySQLCapabilities.all {
            if contains(flag) {
                desc.append(name)
            }
        }
        return desc.joined(separator: " | ")
    }
}
