import Foundation
import Core
import TCP
import Dispatch

struct Capabilities : OptionSet, ExpressibleByIntegerLiteral {
    var rawValue: UInt32
    
    static let protocol41: Capabilities = 0x0200
    static let longFlag: Capabilities = 0x0004
    static let connectWithDB: Capabilities = 0x0008
    static let secureConnection: Capabilities = 0x8000
    
    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    init(integerLiteral value: UInt32) {
        self.rawValue = value
    }
}

final class Connection {
    let socket: Socket
    let queue: DispatchQueue
    let buffer: MutableByteBuffer
    let parser: PacketParser
    var handshake: Handshake?
    var source: DispatchSourceRead
    let username: String
    let password: String?
    let database: String?
    
    var authenticated: Bool?
    
    var capabilities: Capabilities {
        var base: Capabilities = [
            .protocol41, .longFlag, .secureConnection
        ]
        
        if database != nil {
            base.update(with: .connectWithDB)
        }
        
        return base
    }
    
    var mysql41: Bool {
        // client && server 4.1 support
        return handshake?.isGreaterThan4 == true && self.capabilities.contains(.protocol41) && handshake?.capabilities.contains(.protocol41) == true
    }
    
    public var initialized: Bool {
        return self.handshake != nil
    }
    
    init(hostname: String, port: UInt16 = 3306, user: String, password: String?, database: String?, queue: DispatchQueue) throws {
        let socket = try Socket()
        
        let bufferSize = Int(UInt16.max)
        
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        let buffer = MutableByteBuffer(start: pointer, count: bufferSize)
        
        try socket.connect(hostname: hostname, port: port)
        
        let parser = PacketParser()
        
        let source = socket.onReadable(queue: queue) {
            do {
                let usedBufferSize = try socket.read(max: bufferSize, into: buffer)
                
                // Reuse existing pointer to data
                let newBuffer = MutableByteBuffer(start: pointer, count: usedBufferSize)
                
                parser.inputStream(newBuffer)
            } catch {
                socket.close()
            }
        }
        
        self.parser = parser
        self.socket = socket
        self.queue = queue
        self.buffer = buffer
        self.source = source
        self.username = user
        self.password = password
        self.database = database
        
        self.parser.drain(self.handlePacket)
    }
    
    func handlePacket(_ packet: Packet) {
        guard let handshake = self.handshake else {
            do {
                let handshake = try packet.parseHandshake()
                self.handshake = handshake
                
                try self.sendHandshake()
            } catch {
                self.socket.close()
            }
            
            return
        }
        
        guard let authenticated = authenticated else {
            do {
                let response = try packet.parseResponse(mysql41: self.mysql41)
                
                switch response {
                case .error(let error):
                    print(error)
                    // Unauthenticated
                    self.socket.close()
                    return
                default:
                    return
                }
            } catch {
                self.socket.close()
            }
            return
        }
        
        guard authenticated else {
            self.socket.close()
            return
            //MySQLError.unauthenticated
        }
        
        return
    }
    
    func write(packetFor data: ByteBuffer) throws {
        var offset = 0
        
        guard let input = data.baseAddress else {
            throw MySQLError.invalidPacket
        }
        
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: Packet.maxPayloadSize &+ 4)
        
        defer {
            pointer.deallocate(capacity: Packet.maxPayloadSize &+ 4)
        }
        
        var packetNumber: UInt8 = 1
        
        while offset < data.count {
            defer {
                packetNumber = packetNumber &+ 1
            }
            
            let dataSize = min(Packet.maxPayloadSize, data.count &- offset)
            let packetSize = UInt32(dataSize)
            
            let packetSizeBytes = [
                UInt8((packetSize) & 0xff),
                UInt8((packetSize >> 8) & 0xff),
                UInt8((packetSize >> 16) & 0xff),
            ]
            
            defer {
                offset = offset + dataSize
            }
            
            memcpy(pointer, packetSizeBytes, 3)
            pointer[3] = packetNumber
            memcpy(pointer.advanced(by: 4), input.advanced(by: offset), dataSize)
            
            let buffer = ByteBuffer(start: pointer, count: dataSize &+ 4)
            _ = try self.socket.write(max: dataSize &+ 4, from: buffer)
        }
        
        return
    }
}
