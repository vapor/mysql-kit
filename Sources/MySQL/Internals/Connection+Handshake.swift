import Async
import Bits
import Crypto
import Foundation
import TCP

extension MySQLConnection {
    /// Creates a new connection and completes the handshake
    public static func makeConnection(
        hostname: String,
        port: UInt16 = 3306,
        ssl: MySQLSSLConfig? = nil,
        user: String,
        password: String?,
        database: String,
        on eventLoop: EventLoop
    ) -> Future<MySQLConnection> {
        return Future {
            let socket = try TCPSocket(isNonBlocking: true)
            let client = try TCPClient(socket: socket)
            
            let state = MySQLStateMachine(
                source: socket.source(on: eventLoop),
                sink: socket.sink(on: eventLoop),
                user: user,
                password: password,
                database: database,
                ssl: ssl,
                worker: eventLoop
            )
            
            try client.connect(hostname: hostname, port: port)
            
            return state.connected.future.transform(to: MySQLConnection(stateMachine: state))
        }
    }
}

/// This library's capabilities
var capabilities: Capabilities {
    let base: Capabilities = [
        .longPassword, .protocol41, .longFlag, .connectWithDB, .secureConnection
    ]
    
    return base
}

extension MySQLStateMachine {
    func doHandshake(from input: Packet) throws -> Packet {
        let handshake = try input.parseHandshake()
        self.handshake = handshake
        self.state = .sentHandshake
        return try self.makeHandshake(for: handshake)
    }
    
    /// Send the handshake to the client
    func makeHandshake(for handshake: Handshake) throws -> Packet {
        self.sequenceId += 1
        
        if handshake.isGreaterThan4 {
            var data = Data()
            
            let combinedCapabilities = capabilities.rawValue & handshake.capabilities.rawValue
            
            data.append(contentsOf: [
                UInt8((combinedCapabilities) & 0xff),
                UInt8((combinedCapabilities >> 8) & 0xff),
                UInt8((combinedCapabilities >> 16) & 0xff),
                UInt8((combinedCapabilities >> 24) & 0xff),
            ])
            
            // UInt32(0) for the maximum packet length, or, undefined
            // pointer is already 0 here
            data.append(contentsOf: [0,0,0,0])
            
            data.append(handshake.defaultCollation)
            
            // 23 reserved space
            data.append(contentsOf: [UInt8](repeating: 0, count: 23))
            
            // user + null terminator
            data.append(contentsOf: self.user.utf8)
            data.append(0)
            
            if let password = password, handshake.capabilities.contains(.secureConnection) {
                let hash = sha1Encrypted(from: password, seed: handshake.randomSeed)
                
                // SHA1.digestSize == 20
                data.append(numericCast(hash.count))
                data.append(hash)
            } else {
                data.append(0)
            }
            
            if handshake.capabilities.contains(.connectWithDB) {
                data.append(contentsOf: database.utf8)
                data.append(0)
            }
            
            let packet = Packet(data: data)
            packet.sequenceId = self.sequenceId
            return packet
        } else {
            throw MySQLError(.invalidHandshake)
        }
    }
    
    func sha1Encrypted(from password: String, seed: [UInt8]) -> Data {
        let hashedPassword = SHA1.hash(password)
        let doublePasswordHash = SHA1.hash(hashedPassword)
        var hash = SHA1.hash(seed + doublePasswordHash)
        
        for i in 0..<20 {
            hash[i] = hash[i] ^ hashedPassword[i]
        }
        
        return hash
    }
    
    /// Parse the authentication request
    func finishAuthentication(for packet: Packet) throws -> Packet? {
        self.sequenceId += 1
        
        switch packet.payload.first {
        case 0xfe:
            if packet.payload.count == 0 {
                throw MySQLError(.invalidHandshake)
            } else {
                var offset = 1
                
                while offset < packet.payload.count, packet.payload[offset] != 0x00 {
                    offset = offset &+ 1
                }
                
                guard
                    offset < packet.payload.count,
                    let password = self.password,
                    let mechanism = String(bytes: packet.payload[1..<offset], encoding: .utf8)
                    else {
                        throw MySQLError(.invalidHandshake)
                }
                
                switch mechanism {
                case "mysql_native_password":
                    guard offset &+ 2 < packet.payload.count else {
                        throw MySQLError(.invalidHandshake)
                    }
                    
                    let hash = sha1Encrypted(from: password, seed: Array(packet.payload[(offset &+ 1)...]))
                    
                    let packet = Packet(data: hash)
                    packet.sequenceId = self.sequenceId
                    return packet
                case "mysql_clear_password":
                    let packet = Packet(data: Data(password.utf8))
                    packet.sequenceId = self.sequenceId
                    return packet
                default:
                    throw MySQLError(.invalidHandshake)
                }
            }
        case 0xff:
            throw MySQLError(packet: packet)
        default:
            // auth is finished, have the parser stream to the packet stream now
            return nil
        }
    }
}

extension Handshake {
    /// If `true`, both parties support MySQL's v4.1 protocol
    var mysql41: Bool {
        // client && server 4.1 support
        return self.isGreaterThan4 == true && capabilities.contains(.protocol41) && self.capabilities.contains(.protocol41) == true
    }
}
