import Bits
import Debugging

/// Protocol::Handshake
///
/// When the client connects to the server the server sends a handshake packet to the client.
/// Depending on the server version and configuration options different variants of the initial packet are sent.
///
/// https://dev.mysql.com/doc/internals/en/connection-phase-packets.html#packet-Protocol::Handshake
public struct MySQLHandshakeV10 {
    /// protocol_version (1) -- 0x0a protocol_version
    public var protocolVersion: Byte

    /// server_version (string.NUL) -- human-readable server version
    public var serverVersion: String

    /// connection_id (4) -- connection id
    public var connectionID: UInt32

    /// auth_plugin_data_part_1 (string.fix_len) -- [len=8] first 8 bytes of the auth-plugin data
    public var authPluginData: String

    /// The server's capabilities.
    public var capabilityFlags: MySQLCapabilityFlags

    /// character_set (1) -- default server character-set, only the lower 8-bits Protocol::CharacterSet (optional)
    public var characterSet: Byte?

    /// status_flags (2) -- Protocol::StatusFlags (optional)
    public var statusFlags: UInt16?

    /// auth_plugin_name (string.NUL) -- name of the auth_method that the auth_plugin_data belongs to
    public var authPluginName: String?

    /// Parses a `MySQLHandshakeV10` from the `ByteBuffer`.
    public init(bytes: inout ByteBuffer, source: SourceLocation) throws {
        let protocolVersion = bytes.assertReadInteger(endianness: .little, as: Byte.self)
        self.protocolVersion = protocolVersion
        assert(protocolVersion == 0x0a, "mysql wire protocol v10 required")
        
        self.serverVersion = bytes.assertReadNullTerminatedString()
        self.connectionID = bytes.assertReadInteger(endianness: .little)
        let authPluginDataPart1 = bytes.assertReadString(length: 8)
        let filler_1 = bytes.assertReadInteger(as: Byte.self)
        // filler_1 (1) -- 0x00
        assert(filler_1 == 0x00)
        // capability_flag_1 (2) -- lower 2 bytes of the Protocol::CapabilityFlags (optional)
        let capabilityFlag1 = bytes.assertReadInteger(endianness: .little, as: UInt16.self)

        if bytes.readableBytes > 0 {
            self.characterSet = bytes.assertReadInteger(endianness: .little)
            self.statusFlags = bytes.assertReadInteger(endianness: .little)

            // capability_flags_2 (2) -- upper 2 bytes of the Protocol::CapabilityFlags
            self.capabilityFlags = MySQLCapabilityFlags(
                upper: bytes.assertReadInteger(endianness: .little),
                lower: capabilityFlag1
            )

            let authPluginDataLength: Byte?
            if capabilityFlags.CLIENT_PLUGIN_AUTH {
                authPluginDataLength = bytes.assertReadInteger(endianness: .little)
            } else {
                let authPluginDataLengthFiller = bytes.assertReadInteger(endianness: .little, as: Byte.self)
                assert(authPluginDataLengthFiller == 0x00, "invalid auth plugin data filler: \(authPluginDataLengthFiller)")
                authPluginDataLength = nil
            }

            /// string[10]     reserved (all [00])
            let reserved = bytes.assertReadBytes(length: 10)
            assert(reserved == [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

            if capabilityFlags.CLIENT_SECURE_CONNECTION, let authPluginDataLength = authPluginDataLength, authPluginDataLength > 0 {
                let len = max(13, authPluginDataLength - 8)
                let authPluginDataPart2 = bytes.assertReadString(length: numericCast(len))

                self.authPluginData = authPluginDataPart1 + authPluginDataPart2
            } else {
                self.authPluginData = authPluginDataPart1
            }

            if capabilityFlags.CLIENT_PLUGIN_AUTH {
                self.authPluginName = bytes.assertReadNullTerminatedString()
            }
        } else {
            self.capabilityFlags = .init(lower: capabilityFlag1)
            self.authPluginData = authPluginDataPart1
        }

        assert(bytes.readableBytes == 0, "excess data remaining")
    }
}