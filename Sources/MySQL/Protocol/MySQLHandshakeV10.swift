import Bits
import Foundation

/// Protocol::Handshake
///
/// When the client connects to the server the server sends a handshake packet to the client.
/// Depending on the server version and configuration options different variants of the initial packet are sent.
///
/// https://dev.mysql.com/doc/internals/en/connection-phase-packets.html#packet-Protocol::Handshake
struct MySQLHandshakeV10 {
    /// protocol_version (1) -- 0x0a protocol_version
    var protocolVersion: Byte

    /// server_version (string.NUL) -- human-readable server version
    var serverVersion: String

    /// connection_id (4) -- connection id
    var connectionID: UInt32

    /// auth_plugin_data_part_1 (string.fix_len) -- [len=8] first 8 bytes of the auth-plugin data
    var authPluginData: Data

    /// The server's capabilities.
    var capabilities: MySQLCapabilities

    /// character_set (1) -- default server character-set, only the lower 8-bits Protocol::CharacterSet (optional)
    var characterSet: MySQLCharacterSet?

    /// status_flags (2) -- Protocol::StatusFlags (optional)
    var statusFlags: UInt16?

    /// auth_plugin_name (string.NUL) -- name of the auth_method that the auth_plugin_data belongs to
    var authPluginName: String?

    /// Parses a `MySQLHandshakeV10` from the `ByteBuffer`.
    init(bytes: inout ByteBuffer) throws {
        let protocolVersion = try bytes.requireInteger(endianness: .little, as: Byte.self, source: .capture())
        self.protocolVersion = protocolVersion
        guard protocolVersion == 0x0a else {
            throw MySQLError(identifier: "protocolVersion", reason: "Invalid protocol verison: \(protocolVersion)", source: .capture())
        }
        
        self.serverVersion = try bytes.requireNullTerminatedString(source: .capture())
        self.connectionID = try bytes.requireInteger(endianness: .little, source: .capture())
        let authPluginDataPart1 = try bytes.requireBytes(length: 8, source: .capture())
        let filler_1 = try bytes.requireInteger(as: Byte.self, source: .capture())
        // filler_1 (1) -- 0x00
        assert(filler_1 == 0x00)
        // capability_flag_1 (2) -- lower 2 bytes of the Protocol::CapabilityFlags (optional)
        let capabilityFlag1 = try bytes.requireInteger(endianness: .little, as: UInt16.self, source: .capture())

        if bytes.readableBytes > 0 {
            self.characterSet = try .init(byte: bytes.requireInteger(endianness: .little, source: .capture()))
            self.statusFlags = try bytes.requireInteger(endianness: .little, source: .capture())

            // capability_flags_2 (2) -- upper 2 bytes of the Protocol::CapabilityFlags
            self.capabilities = MySQLCapabilities(
                upper: try bytes.requireInteger(endianness: .little, source: .capture()),
                lower: capabilityFlag1
            )

            let authPluginDataLength: Byte
            if capabilities.get(CLIENT_PLUGIN_AUTH) {
                authPluginDataLength = try bytes.requireInteger(endianness: .little, source: .capture())
            } else {
                authPluginDataLength = try bytes.requireInteger(endianness: .little, source: .capture())
                assert(authPluginDataLength == 0x00, "invalid auth plugin data filler: \(authPluginDataLength)")
            }

            /// string[10]     reserved (all [00])
            let reserved = try bytes.requireBytes(length: 10, source: .capture())
            assert(reserved == [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

            if capabilities.get(CLIENT_SECURE_CONNECTION), authPluginDataLength > 0 {
                let len = max(13, authPluginDataLength - 8)
                let authPluginDataPart2 = try bytes.requireBytes(length: numericCast(len), source: .capture())

                self.authPluginData = Data(authPluginDataPart1 + authPluginDataPart2)
            } else {
                self.authPluginData = Data(authPluginDataPart1)
            }

            if capabilities.get(CLIENT_PLUGIN_AUTH) {
                self.authPluginName = try bytes.requireNullTerminatedString(source: .capture())
            }
        } else {
            self.capabilities = .init(lower: capabilityFlag1)
            self.authPluginData = Data(authPluginDataPart1)
        }
    }
}
