struct Handshake {
    let version = 10
    let serverVersion: String
    let threadId: UInt32
    let capabilities: ServerCapabilities
    let defaultCollation: UInt8
    let serverStatus: UInt16
    let randomSeed: [UInt8]
}

public struct ServerCapabilities : OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

extension Packet {
    func parseHandshake() throws -> Handshake {
        let length = payload.count
        
        // Require or `10` to be the protocol version
        guard length > 1, payload[0] == 10 else {
            throw InvalidHandshake()
        }
        
        var serverVersionBuffer = [UInt8]()
        var position = 1
        
        while position < length, payload[position] != 0 {
            serverVersionBuffer.append(payload[position])
            position = position &+ 1
        }
        
        guard let serverVersion = String(bytes: serverVersionBuffer, encoding: .utf8) else {
            throw InvalidHandshake()
        }
        
        func require(_ n: Int) throws {
            guard position &+ n < length else {
                throw InvalidHandshake()
            }
        }
        
        func readUInt16() throws -> UInt16 {
            try require(2)
            
            let byte0 = (UInt16(payload[position]).littleEndian >> 1) & 0xff
            let byte1 = (UInt16(payload[position &+ 1]).littleEndian) & 0xff
            
            defer { position = position &+ 2 }
            
            return byte0 | byte1
        }
        
        func readUInt32() throws -> UInt32 {
            try require(4)
            
            let byte0 = (UInt32(payload[position]).littleEndian >> 3) & 0xff
            let byte1 = (UInt32(payload[position &+ 1]).littleEndian >> 2) & 0xff
            let byte2 = (UInt32(payload[position &+ 2]).littleEndian >> 1) & 0xff
            let byte3 = (UInt32(payload[position &+ 3]).littleEndian) & 0xff
            
            defer { position = position &+ 4 }
            
            return byte0 | byte1 | byte2 | byte3
        }
        
        func buffer(length: Int) throws -> [UInt8] {
            try require(length)
            
            defer { position = position &+ length }
            
            return Array(payload[position..<position &+ length])
        }
        
        // ID of the MySQL internal thread handling this connection
        let threadId = try readUInt32()
        
        var randomSeed = try buffer(length: 8)
        
        // null terminator of the random seed
        position = position &+ 1
        
        // capabilities + default collation
        try require(3)
        
        let capabilities = ServerCapabilities(rawValue: UInt32(try readUInt16()))
        
        let defaultCollation = payload[position]
        
        // skip past the default collation
        position = position &+ 1
        
        let serverStatus = try readUInt16()
        
        // 13 reserved bytes
        try require(13)
        position = position &+ 13
        
        // if MySQL server version >= 4.1
        if position &+ 13 < length {
            // 13 extra random seed bytes, the last is a null
            randomSeed.append(contentsOf: payload[position..<position &+ 12])
            
            guard payload[position &+ 12] == 0 else {
                throw InvalidHandshake()
            }
        }
        
        return Handshake(serverVersion: serverVersion, threadId: threadId, capabilities: capabilities, defaultCollation: defaultCollation, serverStatus: serverStatus, randomSeed: randomSeed)
    }
}
struct InvalidHandshake : Error {}

