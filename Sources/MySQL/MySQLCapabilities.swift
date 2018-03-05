/// The capability flags are used by the client and server to indicate which features they support and want to use.
///
/// https://dev.mysql.com/doc/internals/en/capability-flags.html#packet-Protocol::CapabilityFlags
public struct MySQLCapabilities {
    /// The raw capability value.
    public var raw: UInt32

    /// Create a new `MySQLCapabilityFlags` from the upper and lower values.
    public init(upper: UInt16? = nil, lower: UInt16) {
        var raw: UInt32 = 0
        if let upper = upper {
            raw = numericCast(lower)
            raw |= numericCast(upper) << 16
        } else {
            raw = numericCast(lower)
        }
        self.raw = raw
    }

    /// Returns true if the capability is enabled.
    public  func get(_ flag: UInt32) -> Bool {
        return raw & flag > 0
    }

    /// Enables or disables a capability.
    public mutating func set(_ capability: MySQLCapability, to enabled: Bool) {
        if enabled {
            raw |= capability
        } else {
            raw &= ~capability
        }
    }
}

extension MySQLCapabilities: ExpressibleByDictionaryLiteral {
    /// See `ExpressibleByDictionaryLiteral.init(dictionaryLiteral)`
    public init(dictionaryLiteral elements: (MySQLCapability, Bool)...) {
        var capabilities = MySQLCapabilities(lower: 0)
        for (capability, enabled) in elements {
            capabilities.set(capability, to: enabled)
        }
        self = capabilities
    }
}

extension MySQLCapabilities: ExpressibleByArrayLiteral {
    /// See `ExpressibleByDictionaryLiteral.init(arrayLiteral)`
    public init(arrayLiteral elements: MySQLCapability...) {
        var capabilities = MySQLCapabilities(lower: 0)
        for capability in elements {
            capabilities.set(capability, to: true)
        }
        self = capabilities
    }
}

public typealias MySQLCapability = UInt32

/// Server: Sends extra data in Initial Handshake Packet and supports the pluggable authentication protocol.
/// Client: Supports authentication plugins.
/// Requires: CLIENT_PROTOCOL_41
public var CLIENT_PLUGIN_AUTH: MySQLCapability = 0x00080000

/// Server: Supports Authentication::Native41.
/// Client: Supports Authentication::Native41.
public var CLIENT_SECURE_CONNECTION: MySQLCapability = 0x00008000

/// Server: Supports the 4.1 protocol.
/// Client: Uses the 4.1 protocol.
/// note: this value was CLIENT_CHANGE_USER in 3.22, unused in 4.0
public var CLIENT_PROTOCOL_41: MySQLCapability = 0x00000200

/// Server: Understands length-encoded integer for auth response data in Protocol::HandshakeResponse41.
/// Client: Length of auth response data in Protocol::HandshakeResponse41 is a length-encoded integer.
/// note: The flag was introduced in 5.6.6, but had the wrong value.
public var CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA: MySQLCapability = 0x00200000

/// Database (schema) name can be specified on connect in Handshake Response Packet.
/// Server: Supports schema-name in Handshake Response Packet.
/// Client: Handshake Response Packet contains a schema-name.
public var CLIENT_CONNECT_WITH_DB: MySQLCapability = 0x00000008

/// Server: Permits connection attributes in Protocol::HandshakeResponse41.
/// Client: Sends connection attributes in Protocol::HandshakeResponse41.
public var CLIENT_CONNECT_ATTRS: MySQLCapability = 0x00100000
