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
            
            let connector = try MySQLConnector(
                source: socket.source(on: eventLoop),
                sink: socket.sink(on: eventLoop),
                user: user,
                password: password,
                database: database,
                ssl: ssl,
                on: eventLoop
            )
            
            try client.connect(hostname: hostname, port: port)
            
            return connector.promise.future
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

extension Handshake {
    /// If `true`, both parties support MySQL's v4.1 protocol
    var mysql41: Bool {
        // client && server 4.1 support
        return self.isGreaterThan4 == true && capabilities.contains(.protocol41) && self.capabilities.contains(.protocol41) == true
    }
}

fileprivate final class MySQLConnector: TranslatingStream {
    typealias Input = Packet
    typealias Output = Packet
    
    enum ConnectionState {
        case start, sentHandshake, sentSSL
    }
    
    let user: String
    let password: String?
    let database: String
    let ssl: MySQLSSLConfig?
    let eventLoop: EventLoop
    
    let parser: TranslatingStreamWrapper<MySQLPacketParser>
    let _serializer: MySQLPacketSerializer
    let serializer: PushStream<Packet>
    let serializeStream: TranslatingStreamWrapper<MySQLPacketSerializer>
    let passthrough: ConnectingStream<Packet>
    fileprivate let promise: Promise<MySQLConnection>
    var completed: Bool
    
    var state: ConnectionState
    var handshake: Handshake?
    
    init<S>(
        source: SocketSource<S>,
        sink: SocketSink<S>,
        user: String,
        password: String?,
        database: String,
        ssl: MySQLSSLConfig?,
        on eventLoop: EventLoop
    ) throws {
        self.state = .start
        self.user = user
        self.password = password
        self.database = database
        self.passthrough = .init()
        self.ssl = ssl
        self.eventLoop = eventLoop
        self.serializer = .init()
        self.promise = .init()
        self._serializer = MySQLPacketSerializer()
        self.completed = false
        self.serializeStream = _serializer.stream(on: eventLoop)
        self.parser = source.stream(to: MySQLPacketParser().stream(on: eventLoop))
        
        let connectingStream = self.stream(on: eventLoop)
        serializer.stream(to: serializeStream).output(to: sink)
        
        connectingStream.drain { packet, upstream in
            self.serializer.next(packet)
            upstream.request()
        }.upstream?.request()
        
        self.parser.output(to: connectingStream)
    }
    
    fileprivate func complete() throws {
        guard let handshake = self.handshake else {
            throw MySQLError(.invalidHandshake)
        }
        
        let connection = MySQLConnection(
            handshake: handshake,
            parser: passthrough,
            serializer: serializer
        )
        
        // reset
        _serializer.sequenceId = 0
        self.parser.stream(to: self.passthrough).output(to: serializeStream)
        self.completed = true
        
        promise.complete(connection)
    }
    
    func translate(input: Packet) throws -> Future<TranslatingStreamResult<Packet>> {
        func doHandshake() throws -> Future<TranslatingStreamResult<Packet>> {
            let handshake = try input.parseHandshake()
            self.handshake = handshake
            self.state = .sentHandshake
            return try Future(.sufficient(self.makeHandshake(for: handshake)))
        }
        
        do {
            // https://mariadb.com/kb/en/library/1-connecting-connecting/
            switch self.state {
            case .start:
                if  let ssl = self.ssl, capabilities.contains(.ssl) {
                    _ = ssl
                    fatalError("Unsupported StartTLS")
                    // Do SSL upgrade
                    // self.state = .sendSSL
                } else {
                    return try doHandshake()
                }
            case .sentSSL:
                return try doHandshake()
            case .sentHandshake:
                guard let packet = try self.finishAuthentication(for: input) else {
                    try complete()
                    return Future(.insufficient)
                }
                
                return Future(.sufficient(packet))
            }
        } catch {
            promise.fail(error)
            
            return Future(.sufficient([0x01])) // close
        }
    }
    
    /// Send the handshake to the client
    func makeHandshake(for handshake: Handshake) throws -> Packet {
        self._serializer.sequenceId += 1
        
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
            
            return Packet(data: data)
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
        self._serializer.sequenceId += 1
        
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
                    
                    return Packet(data: hash)
                case "mysql_clear_password":
                    return Packet(data: Data(password.utf8))
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


