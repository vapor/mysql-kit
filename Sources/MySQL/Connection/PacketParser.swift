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
internal final class MySQLPacketParser: ByteParserStream {
    enum ParsingState {
        case header([UInt8])
        case packet(ParsingPacket)
    }
    
    struct ParsingPacket {
        var buffer: MutableByteBuffer
        var containing: Int
    }
    
    typealias Partial = ParsingState
    
    var state: ByteParserStreamState<MySQLPacketParser>
    
    typealias Output = Packet
    
    /// See InputStream.Input
    typealias Input = ByteBuffer
    
    /// Create a new packet parser
    init(eventloop: EventLoop) {
        self.state = .init(worker: eventloop)
    }
    
    func continueParsing(_ partial: Partial, from input: ByteBuffer) throws -> ByteParserResult<Partial, Output> {
        switch partial {
        case .header(let bytes):
            switch parseHeader(from: input, expanding: bytes) {
            case .uncompleted(let partialHeader):
                return .uncompleted(.header(partialHeader))
            case .completed(let consumed, let header):
                let fullPacketSize = 1 &+ header
                
                if input.count < fullPacketSize {
                    let partial = dumpPayload(
                        size: fullPacketSize,
                        from: ByteBuffer(start: input.baseAddress?.advanced(by: consumed), count: input.count - consumed)
                    )
                    
                    return .uncompleted(.packet(partial))
                } else {
                    return .completed(
                        consuming: consumed &+ fullPacketSize,
                        result: Packet(payload:
                            ByteBuffer(start: input.baseAddress?.advanced(by: consumed), count: fullPacketSize)
                        )
                    )
                }
            }
        case .packet(let packet):
            let buffer = packet.buffer
            
            let dataSize = min(buffer.count &- packet.containing, input.count)
            
            memcpy(packet.buffer.baseAddress!.advanced(by: packet.containing), input.baseAddress!, dataSize)
            
            if dataSize &+ packet.containing == buffer.count {
                // Packet is complete, send it up
                let packet = Packet(payload: buffer)
                return .completed(consuming: dataSize, result: packet)
            } else {
                // Wait for more data
                let packet = ParsingPacket(buffer: packet.buffer, containing: dataSize &+ packet.containing)
                return .uncompleted(.packet(packet))
            }
        }
    }
    
    func startParsing(from buffer: ByteBuffer) throws -> ByteParserResult<Partial, Output> {
        let pointer = buffer.baseAddress!
        
        guard buffer.count >= 3 else {
            let header = dumpHeader(from: buffer)
            return .uncompleted(.header(header))
        }
        
        let byte0: UInt32 = (numericCast(pointer[0]) as UInt32).littleEndian
        let byte1: UInt32 = (numericCast(pointer[1]) as UInt32).littleEndian << 8
        let byte2: UInt32 = (numericCast(pointer[2]) as UInt32).littleEndian << 16
        
        let payloadSize = numericCast(byte0 | byte1 | byte2) as Int
        
        // sequenceID + payload
        let fullPacketSize = 1 &+ payloadSize
        
        if buffer.count < fullPacketSize {
            let partial = dumpPayload(
                size: payloadSize,
                from: ByteBuffer(start: pointer.advanced(by: 3), count: buffer.count - 3)
            )
            
            return .uncompleted(.packet(partial))
        } else {
            return .completed(
                consuming: 3 &+ fullPacketSize,
                result: Packet(payload:
                    ByteBuffer(start: pointer.advanced(by: 3), count: fullPacketSize)
                )
            )
        }
    }
    
    private func dumpHeader(from buffer: ByteBuffer, expanding header: [UInt8] = []) -> [UInt8] {
        guard header.count &+ buffer.count < 3 else {
            fatalError("Dumping MySQL packet header which is large enough to parse")
        }
        
        let pointer = buffer.baseAddress!
        
        // at least 4 packet bytes for new packets
        if buffer.count == 0 {
            return header
        }
        
        switch buffer.count {
        case 1:
            return header + [
                pointer[0]
            ]
        case 2:
            return header + [
                pointer[0], pointer[1]
            ]
        default:
            return [
                pointer[0], pointer[1], pointer[1]
            ]
        }
    }
    
    private func dumpPayload(size: Int, from buffer: ByteBuffer) -> ParsingPacket {
        // dump payload inside packet
        // Build a buffer size, we need to copy this since it's not complete
        let bufferPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        let buffer = MutableByteBuffer(start: bufferPointer, count: size)
        
        let containing = min(buffer.count, size)
        memcpy(bufferPointer, buffer.baseAddress!, containing)
        
        return ParsingPacket(buffer: buffer, containing: 0)
    }
    
    /// Do not call this function is the headerBytes size == 0
    private func parseHeader(from buffer: ByteBuffer, expanding headerBytes: [UInt8]) -> ByteParserResult<[UInt8], Int> {
        guard headerBytes.count > 0 else {
            fatalError("Incorrect usage of MySQL packet header parsing")
        }
        
        guard buffer.count &+ headerBytes.count >= 3 else {
            return .uncompleted(dumpHeader(from: buffer))
        }
        
        let pointer = buffer.baseAddress!
        
        let byte0: UInt32
        let byte1: UInt32
        let byte2: UInt32
        var consumed: Int
        
        // take the first 3 bytes
        // Take the cached previous packet edge-case bytes into consideration
        switch headerBytes.count {
        case 1:
            byte0 = (numericCast(headerBytes[0]) as UInt32).littleEndian
            
            byte1 = (numericCast(pointer[0]) as UInt32).littleEndian << 8
            byte2 = (numericCast(pointer[1]) as UInt32).littleEndian << 16
            consumed = 2
        case 2:
            byte0 = (numericCast(headerBytes[0]) as UInt32).littleEndian
            byte1 = (numericCast(headerBytes[1]) as UInt32).littleEndian << 8
            
            byte2 = (numericCast(pointer[0]) as UInt32).littleEndian << 16
            consumed = 1
        default:
            fatalError("Invalid scenario reached")
        }
        
        return .completed(consuming: consumed, result: numericCast(byte0 | byte1 | byte2))
    }
}

extension Packet {
    /// Parses the field definition from a packet
    func parseFieldDefinition() throws -> Field {
        var parser = Parser(packet: self)
        
        try parser.skipLenEnc() // let catalog = try parser.parseLenEncString()
        try parser.skipLenEnc() // let database = try parser.parseLenEncString()
        try parser.skipLenEnc() // let table = try parser.parseLenEncString()
        try parser.skipLenEnc() // let originalTable = try parser.parseLenEncString()
        let name = try parser.parseLenEncString()
        try parser.skipLenEnc() // let originalName = try parser.parseLenEncString()
        
        parser.position += 1
        
        let charSet = try parser.byte()
        let collation = try parser.byte()
        
        let length = try parser.parseUInt32()
        
        guard let fieldType = Field.FieldType(rawValue: try parser.byte()) else {
            throw MySQLError(.invalidPacket)
        }
        
        let flags = Field.Flags(rawValue: try parser.parseUInt16())
        
        let decimals = try parser.byte()
        
        return Field(
            catalog: nil,
            database: nil,
            table: nil,
            originalTable: nil,
            name: name,
            originalName: nil,
            charSet: charSet,
            collation: collation,
            length: length,
            fieldType: fieldType,
            flags: flags,
            decimals: decimals
        )
    }
}

