/// The capability flags are used by the client and server to indicate which features they support and want to use.
///
/// https://dev.mysql.com/doc/internals/en/capability-flags.html#packet-Protocol::CapabilityFlags
public struct MySQLCapabilityFlags {
    /// The raw capability value.
    private var raw: UInt32

    /// Server: Sends extra data in Initial Handshake Packet and supports the pluggable authentication protocol.
    /// Client: Supports authentication plugins.
    /// Requires: CLIENT_PROTOCOL_41
    public var CLIENT_PLUGIN_AUTH: Bool {
        get { return raw & 0x00080000 > 0 }
        set { raw |= 0x00080000 }
    }

    /// Server: Supports Authentication::Native41.
    /// Client: Supports Authentication::Native41.
    public var CLIENT_SECURE_CONNECTION: Bool {
        get { return raw & 0x00008000 > 0 }
        set { raw |= 0x00008000 }
    }

    /// Create a new `MySQLCapabilityFlags` from the upper and lower values.
    public init(upper: UInt16? = nil, lower: UInt16) {
        var raw: UInt32 = 0
        if let upper = upper {
            raw = numericCast(upper)
            raw += numericCast(lower) << 16
        } else {
            raw = numericCast(lower)
        }
        self.raw = raw
    }
}
