import Bits
import Foundation

extension MySQLPacket {
    /// Protocol::Handshake
    ///
    /// When the client connects to the server the server sends a handshake packet to the client.
    /// Depending on the server version and configuration options different variants of the initial packet are sent.
    ///
    /// https://dev.mysql.com/doc/internals/en/connection-phase-packets.html#packet-Protocol::Handshake
    struct HandshakeV10 {
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
            let protocolVersion = try bytes.requireInteger(endianness: .little, as: Byte.self)
            self.protocolVersion = protocolVersion
            guard protocolVersion == 0x0a else {
                throw MySQLError(identifier: "protocolVersion", reason: "Invalid protocol verison: \(protocolVersion)")
            }
            
            self.serverVersion = try bytes.requireNullTerminatedString()
            self.connectionID = try bytes.requireInteger(endianness: .little)
            let authPluginDataPart1 = try bytes.requireBytes(length: 8)
            let filler_1 = try bytes.requireInteger(as: Byte.self)
            // filler_1 (1) -- 0x00
            assert(filler_1 == 0x00)
            // capability_flag_1 (2) -- lower 2 bytes of the Protocol::CapabilityFlags (optional)
            let capabilityFlag1 = try bytes.requireInteger(endianness: .little, as: UInt16.self)

            if bytes.readableBytes > 0 {
                self.characterSet = try .init(byte: bytes.requireInteger(endianness: .little))
                self.statusFlags = try bytes.requireInteger(endianness: .little)

                // capability_flags_2 (2) -- upper 2 bytes of the Protocol::CapabilityFlags
                self.capabilities = MySQLCapabilities(
                    upper: try bytes.requireInteger(endianness: .little),
                    lower: capabilityFlag1
                )

                let authPluginDataLength: Byte
                if capabilities.contains(.CLIENT_PLUGIN_AUTH) {
                    authPluginDataLength = try bytes.requireInteger(endianness: .little)
                } else {
                    authPluginDataLength = try bytes.requireInteger(endianness: .little)
                    assert(authPluginDataLength == 0x00, "invalid auth plugin data filler: \(authPluginDataLength)")
                }

                /// string[6]     reserved (all [00])
                let reserved = try bytes.requireBytes(length: 6)
                assert(reserved == [0, 0, 0, 0, 0, 0])

                if capabilities.contains(.CLIENT_LONG_PASSWORD) {
                    /// string[4]     reserved (all [00])
                    let reserved2 = try bytes.requireBytes(length: 4)
                    assert(reserved2 == [0, 0, 0, 0])
                } else {
                    /// Capabilities 3rd part. MariaDB specific flags.
                    /// MariaDB Initial Handshake Packet specific flags
                    /// https://mariadb.com/kb/en/library/1-connecting-connecting/
                    let mariaDBSpecific: UInt32 = try bytes.requireInteger(endianness: .little)
                    self.capabilities.mariaDBSpecific = mariaDBSpecific
                }

                if capabilities.contains(.CLIENT_SECURE_CONNECTION) {
                    if capabilities.contains(.CLIENT_PLUGIN_AUTH) {
                        let len = max(13, authPluginDataLength - 8)
                        let authPluginDataPart2 = try bytes.requireBytes(length: numericCast(len))
                        self.authPluginData = Data(authPluginDataPart1 + authPluginDataPart2)
                    } else {
                        let authPluginDataPart2 = try bytes.requireBytes(length: 12)
                        self.authPluginData = Data(authPluginDataPart1 + authPluginDataPart2)
                        let filler: Byte = try bytes.requireInteger()
                        assert(filler == 0x00)
                    }
                } else {
                    self.authPluginData = Data(authPluginDataPart1)
                }

                if capabilities.contains(.CLIENT_PLUGIN_AUTH) {
                    self.authPluginName = try bytes.requireNullTerminatedString()
                }
            } else {
                self.capabilities = .init(lower: capabilityFlag1)
                self.authPluginData = Data(authPluginDataPart1)
            }
        }
    }
}
