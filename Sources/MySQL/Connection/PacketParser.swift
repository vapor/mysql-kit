import Async
import Bits
import COperatingSystem

/// Various states the parser stream can be in
enum ProtocolParserState {
    /// normal state
    case ready
    
    /// waiting for data from upstream
    case awaitingUpstream
}


/// Parses buffers into packets
internal struct MySQLPacketParser: ByteParser {
    enum PartialState {
        case header([UInt8])
        case body(buffer: Packet, containing: Int)
    }
    
    /// See InputStream.Input
    typealias Input = ByteBuffer
    
    /// See OutputStream.RedisData
    typealias Output = Packet
    
    typealias Partial = PartialState
    
    var state: ByteParserState<MySQLPacketParser>
    
    /// Create a new packet parser
    init() {
        state = .init()
    }
    
    func parseBytes(from buffer: ByteBuffer, partial: PartialState?) throws -> Future<ByteParserResult<MySQLPacketParser>> {
        guard let partial = partial else {
            guard let header = parseHeader(from: buffer) else {
                // Not enough bytes
                return Future(.uncompleted(.header(Array(buffer))))
            }
            
            let fullPacketSize = 1 &+ header
            let fullPacket = header &+ 4
            let remainder = buffer.count &- 3
            
            // buffer >= header + (sequenceID + body)
            if buffer.count < fullPacket {
                // Build a buffer size, we need to copy this since it's not complete
                let bufferPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: fullPacketSize)
                
                // dump payload inside packet excluding header
                memcpy(bufferPointer, buffer.baseAddress!.advanced(by: 3), remainder)
                
                let packet = Packet(payload: MutableByteBuffer(start: bufferPointer, count: fullPacketSize))
                
                return Future(
                    .uncompleted(
                        .body(buffer: packet, containing: remainder)
                    )
                )
            } else {
                // Pass a packet pointing to the original buffer
                let buffer = ByteBuffer(start: buffer.baseAddress, count: fullPacket)
                
                let packet = Packet(payload: buffer, containsPacketSize: true)
                return Future(.completed(consuming: fullPacket, result: packet))
            }
        }
        
        switch partial {
        case .header(let header):
            guard let (size, offset) = parseHeader(headerBytes: header, buffer: buffer) else {
                return Future(
                    .uncompleted(
                        .header(header + Array(buffer))
                    )
                )
            }
            
            // sequenceID + payload
            let fullPacketSize = 1 &+ size
            let remainder = buffer.count &- offset
            
            if remainder < fullPacketSize {
                // Build a buffer size, we need to copy this since it's not complete
                let bufferPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: fullPacketSize)
                
                memcpy(bufferPointer, buffer.baseAddress!.advanced(by: offset), remainder)
                
                let packet = Packet(payload: MutableByteBuffer(start: bufferPointer, count: fullPacketSize))
                
                return Future(
                    .uncompleted(
                        .body(buffer: packet, containing: remainder)
                    )
                )
            } else {
                let buffer = ByteBuffer(start: buffer.baseAddress!.advanced(by: offset), count: fullPacketSize)
                
                let packet = Packet(payload: buffer, containsPacketSize: false)
                return Future(.completed(consuming: fullPacketSize, result: packet))
            }
        case .body(let packet, let containing):
            let dataSize = min(packet.buffer.count &- containing, packet.buffer.count)
            let pointer = buffer.baseAddress!
            
            guard case .mutable(let buffer) = packet._buffer else {
                fatalError("Incorrect internal packet parsing state")
            }
            
            memcpy(buffer.baseAddress!.advanced(by: containing), pointer, dataSize)
            
            let newContaining = containing &+ dataSize
            
            if newContaining == buffer.count {
                return Future(.completed(consuming: dataSize, result: packet))
            } else {
                return Future(
                    .uncompleted(
                        .body(buffer: packet, containing: newContaining)
                    )
                )
            }
        }
    }
    
    fileprivate func parseHeader(from buffer: ByteBuffer) -> Int? {
        guard buffer.count >= 3 else { return nil }
        
        let byte0: UInt32 = numericCast(buffer[0])
        let byte1: UInt32 = numericCast(buffer[1])
        let byte2: UInt32 = numericCast(buffer[2])
        
        return numericCast(byte0 | byte1 | byte2) as Int
    }
    
    /// Do not call this function is the headerBytes size == 0
    fileprivate func parseHeader(headerBytes: [UInt8], buffer: ByteBuffer) -> (size: Int, parsed: Int)? {
        guard headerBytes.count > 0 else {
            fatalError("Incorrect usage of MySQL packet header parsing")
        }
        
        guard buffer.count &+ headerBytes.count >= 3 else {
            return nil
        }
        
        let pointer = buffer.baseAddress!
        
        let byte0: UInt32
        let byte1: UInt32
        let byte2: UInt32
        let parsed: Int
        
        // take the first 3 bytes
        // Take the cached previous packet edge-case bytes into consideration
        switch headerBytes.count {
        case 1:
            byte0 = (numericCast(headerBytes[0]) as UInt32).littleEndian
            
            byte1 = (numericCast(pointer[0]) as UInt32).littleEndian << 8
            byte2 = (numericCast(pointer[1]) as UInt32).littleEndian << 16
            parsed = 2
        case 2:
            byte0 = (numericCast(headerBytes[0]) as UInt32).littleEndian
            byte1 = (numericCast(headerBytes[1]) as UInt32).littleEndian << 8
            
            byte2 = (numericCast(pointer[0]) as UInt32).littleEndian << 16
            parsed = 1
        default:
            fatalError("Invalid MySQL parsing scenario reached")
        }
        
        return (numericCast(byte0 | byte1 | byte2) as Int, parsed)
    }
}

extension Packet {
    /// Parses the field definition from a packet
    func parseFieldDefinition() throws -> Field {
        var parser = Parser(packet: self)
        
        try parser.skipLenEnc() // let catalog = try parser.parseLenEncString()
        try parser.skipLenEnc() // let schema = try parser.parseLenEncString()
        try parser.skipLenEnc() // let tableAlias = try parser.parseLenEncString()
        try parser.skipLenEnc() // let table = try parser.parseLenEncString()
        let name = try parser.parseLenEncString()
        try parser.skipLenEnc() // let columnAlias = try parser.parseLenEncString()
        _ = try parser.parseLenEnc() // let originalName = try parser.parseLenEncString()
        
        let charSet = try parser.parseUInt16()
        
        let length = try parser.parseUInt32()
        
        guard let fieldType = Field.FieldType(rawValue: try parser.byte()) else {
            throw MySQLError(.invalidPacket)
        }
        
        let flags = Field.Flags(rawValue: try parser.parseUInt16())
        
        return Field(
            catalog: nil,
            database: nil,
            table: nil,
            originalTable: nil,
            name: name,
            originalName: nil,
            charSet: charSet,
            length: length,
            fieldType: fieldType,
            flags: flags,
            decimals: nil
        )
    }
}

