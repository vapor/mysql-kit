/// The capability flags are used by the client and server to indicate which features they support and want to use.
///
/// https://dev.mysql.com/doc/internals/en/capability-flags.html#packet-Protocol::CapabilityFlags
public struct MySQLCapabilities {
    /// The raw capability value.
    private var raw: UInt32

    /// Server: Sends extra data in Initial Handshake Packet and supports the pluggable authentication protocol.
    /// Client: Supports authentication plugins.
    /// Requires: CLIENT_PROTOCOL_41
    public var CLIENT_PLUGIN_AUTH: Bool {
        get { return get(0x00080000) }
        set { set(0x00080000, to: newValue) }
    }

    /// Server: Supports Authentication::Native41.
    /// Client: Supports Authentication::Native41.
    public var CLIENT_SECURE_CONNECTION: Bool {
        get { return get(0x00008000) }
        set { set(0x00008000, to: newValue) }
    }

    /// Server: Supports the 4.1 protocol.
    /// Client: Uses the 4.1 protocol.
    /// note: this value was CLIENT_CHANGE_USER in 3.22, unused in 4.0
    public var CLIENT_PROTOCOL_41: Bool {
        get { return get(0x00000200) }
        set { set(0x00000200, to: newValue) }
    }

    /// Create a new `MySQLCapabilityFlags` from the upper and lower values.
    public init(upper: UInt16? = nil, lower: UInt16) {
        print(upper)
        print(lower)
        var raw: UInt32 = 0
        if let upper = upper {
            raw = numericCast(lower)
            raw |= numericCast(upper) << 16
        } else {
            raw = numericCast(lower)
        }
        self.raw = raw
    }

    private func get(_ flag: UInt32) -> Bool {
        return raw & flag > 0
    }

    private mutating func set(_ flag: UInt32, to enabled: Bool) {
        if enabled {
            raw |= flag
        } else {
            raw &= ~flag
        }
    }
}
