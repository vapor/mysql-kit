import Bits
import Foundation
import Crypto
@testable import MySQL
import XCTest

class MySQLPacketTests: XCTestCase {
    func testHandshakeV10_wireshark() throws {
        var bytes = handshakeV10_wireshark.prepareMySQLPacket()
        let handshakeV10 = try MySQLHandshakeV10(bytes: &bytes)
        XCTAssertEqual(handshakeV10.protocolVersion, 10)
        XCTAssertEqual(handshakeV10.serverVersion, "5.7.18")
        XCTAssertEqual(handshakeV10.connectionID, 5)
        XCTAssertEqual(handshakeV10.authPluginData.count, 21)
        XCTAssertEqual(handshakeV10.capabilities.get(CLIENT_PLUGIN_AUTH), true)
        XCTAssertEqual(handshakeV10.capabilities.get(CLIENT_SECURE_CONNECTION), true)
        XCTAssertEqual(handshakeV10.capabilities.get(CLIENT_PROTOCOL_41), true)
        XCTAssertEqual(handshakeV10.characterSet, 33)
        XCTAssertEqual(handshakeV10.statusFlags, 2)
        XCTAssertEqual(handshakeV10.authPluginName, "mysql_native_password")
    }

    /// https://dev.mysql.com/doc/internals/en/connection-phase-packets.html#packet-Protocol::Handshake
    func testHandshakeV10_example1() throws {
        var bytes = handshakeV10_example1.prepareMySQLPacket()
        let handshakeV10 = try MySQLHandshakeV10(bytes: &bytes)
        XCTAssertEqual(handshakeV10.protocolVersion, 10)
        XCTAssertEqual(handshakeV10.serverVersion, "5.5.2-m2")
        XCTAssertEqual(handshakeV10.connectionID, 11)
        XCTAssertEqual(handshakeV10.authPluginData.count, 8)
        XCTAssertEqual(handshakeV10.capabilities.get(CLIENT_PLUGIN_AUTH), false)
        XCTAssertEqual(handshakeV10.capabilities.get(CLIENT_SECURE_CONNECTION), true)
        XCTAssertEqual(handshakeV10.capabilities.get(CLIENT_PROTOCOL_41), true)
        XCTAssertEqual(handshakeV10.characterSet, 8)
        XCTAssertEqual(handshakeV10.statusFlags, 2)
        XCTAssertEqual(handshakeV10.authPluginName, nil)
    }

    /// https://dev.mysql.com/doc/internals/en/connection-phase-packets.html#packet-Protocol::Handshake
    func testHandshakeV10_example2() throws {
        var bytes = handshakeV10_example2.prepareMySQLPacket()
        let handshakeV10 = try MySQLHandshakeV10(bytes: &bytes)
        XCTAssertEqual(handshakeV10.protocolVersion, 10)
        XCTAssertEqual(handshakeV10.serverVersion, "5.6.4-m7-log")
        XCTAssertEqual(handshakeV10.connectionID, 2646)
        XCTAssertEqual(handshakeV10.authPluginData.count, 21)
        XCTAssertEqual(handshakeV10.capabilities.get(CLIENT_PLUGIN_AUTH), true)
        XCTAssertEqual(handshakeV10.capabilities.get(CLIENT_SECURE_CONNECTION), true)
        XCTAssertEqual(handshakeV10.capabilities.get(CLIENT_PROTOCOL_41), true)
        XCTAssertEqual(handshakeV10.characterSet, 8)
        XCTAssertEqual(handshakeV10.statusFlags, 2)
        XCTAssertEqual(handshakeV10.authPluginName, "mysql_native_password")
    }

    func testHandshakeResponse41_wireshark() throws {
        _ = ByteBufferAllocator().buffer(capacity: 256)
        _ = MySQLHandshakeResponse41(
            capabilities: [CLIENT_PROTOCOL_41],
            maxPacketSize: 1_073_741_824,
            characterSet: 0x0a,
            username: "root",
            authResponse: .init(),
            database: "",
            authPluginName: "mysql_native_password"
        )
    }

    func testHandshakeResponse41_example1() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 256)
        let response = MySQLHandshakeResponse41(
            capabilities: [
                CLIENT_PROTOCOL_41,
                CLIENT_PLUGIN_AUTH,
                CLIENT_SECURE_CONNECTION,
                CLIENT_CONNECT_WITH_DB
            ],
            maxPacketSize: 1_073_741_824,
            characterSet: 0x0a,
            username: "pam",
            authResponse: .init(),
            database: "test",
            authPluginName: "mysql_native_password"
        )
        response.serialize(into: &buffer)
        print(buffer.debugDescription)
    }

    static let allTests = [
        ("testHandshakeV10_wireshark", testHandshakeV10_wireshark),
        ("testHandshakeV10_example1", testHandshakeV10_example1),
        ("testHandshakeV10_example2", testHandshakeV10_example2),
    ]
}

/// MARK: Data

let handshakeV10_wireshark: Bytes = [
    0x4a, 0x00, 0x00, 0x00,
    0x0a,
    0x35, 0x2e, 0x37, 0x2e, 0x31, 0x38, 0x00,
    0x05, 0x00, 0x00, 0x00,
    0x6c, 0x68, 0x74, 0x40, 0x43, 0x19, 0x43, 0x59,
    0x00,
    0xff, 0xff,
    0x21,
    0x02, 0x00,
    0xff, 0xc1,
    0x15,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x43, 0x4a, 0x47, 0x52, 0x26,
    0x73, 0x25, 0x68, 0x25, 0x71, 0x14, 0x3b, 0x00, 0x6d, 0x79, 0x73, 0x71, 0x6c, 0x5f, 0x6e, 0x61, 0x74, 0x69, 0x76, 0x65, 0x5f,
    0x70, 0x61, 0x73, 0x73, 0x77, 0x6f, 0x72, 0x64, 0x00
]

let handshakeV10_example1: Bytes = [
    0x36, 0x00, 0x00, 0x00, 0x0a, 0x35, 0x2e, 0x35, 0x2e, 0x32, 0x2d, 0x6d, 0x32, 0x00, 0x0b, 0x00,
    0x00, 0x00, 0x64, 0x76, 0x48, 0x40, 0x49, 0x2d, 0x43, 0x4a, 0x00, 0xff, 0xf7, 0x08, 0x02, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2a, 0x34, 0x64,
    0x7c, 0x63, 0x5a, 0x77, 0x6b, 0x34, 0x5e, 0x5d, 0x3a, 0x00
]

let handshakeV10_example2: Bytes = [
    0x50, 0x00, 0x00, 0x00, 0x0a, 0x35, 0x2e, 0x36, 0x2e, 0x34, 0x2d, 0x6d, 0x37, 0x2d, 0x6c, 0x6f,
    0x67, 0x00, 0x56, 0x0a, 0x00, 0x00, 0x52, 0x42, 0x33, 0x76, 0x7a, 0x26, 0x47, 0x72, 0x00, 0xff,
    0xff, 0x08, 0x02, 0x00, 0x0f, 0xc0, 0x15, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x2b, 0x79, 0x44, 0x26, 0x2f, 0x5a, 0x5a, 0x33, 0x30, 0x35, 0x5a, 0x47, 0x00, 0x6d, 0x79,
    0x73, 0x71, 0x6c, 0x5f, 0x6e, 0x61, 0x74, 0x69, 0x76, 0x65, 0x5f, 0x70, 0x61, 0x73, 0x73, 0x77,
    0x6f, 0x72, 0x64, 0x00
]

/// MARK: Utilites

extension Array where Element == Byte {
    func allocateBuffer() -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: count)
        buffer.write(bytes: self)
        return buffer
    }

    func prepareMySQLPacket() -> ByteBuffer {
        var buffer = allocateBuffer()
        /// read mysql packet length
        _ = buffer.readInteger(as: Int32.self)
        return buffer
    }
}
