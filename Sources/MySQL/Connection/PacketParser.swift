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
internal final class MySQLPacketParser: Async.BinaryParsingStream {
    /// Internal buffer that keeps tack of an uncompleted packet header (size: UInt24) + (sequenceID: UInt8)
    private var headerBytes = [UInt8]()
    
    var parsing: Bool
    
    var upstream: ConnectionContext?
    
    var upstreamInput: UnsafeBufferPointer<UInt8>?
    
    var parsedInput: Int
    
    var eventloop: EventLoop
    
    var downstreamDemand: UInt
    
    var partiallyParsed: (buffer: MutableByteBuffer, containing: Int)?
    
    var downstream: AnyInputStream<MySQLPacketParser.Output>?
    
    typealias Output = Packet
    
    /// See InputStream.Input
    typealias Input = ByteBuffer
    
    /// Create a new packet parser
    init(eventloop: EventLoop) {
        downstreamDemand = 0
        parsing = false
        parsedInput = 0
        self.eventloop = eventloop
    }
    
    func continueParsing(_ partial: (buffer: MutableByteBuffer, containing: Int), from input: ByteBuffer) throws -> ParsingState<Output> {
        let (buffer, containing) = partial
        
        let dataSize = min(buffer.count &- containing, input.count)
        
        memcpy(buffer.baseAddress!.advanced(by: containing), input.baseAddress!, dataSize)
        
        if dataSize &+ containing == buffer.count {
            // Packet is complete, send it up
            let packet = Packet(payload: buffer)
            return .completed(consuming: dataSize, result: packet)
        } else {
            // Wait for more data
            self.partiallyParsed = (buffer, dataSize &+ containing)
            return .uncompleted
        }
    }
    
    func startParsing(from buffer: ByteBuffer) throws -> ParsingState<Output> {
        let pointer = buffer.baseAddress!
        
        if headerBytes.count == 0 {
            guard buffer.count >= 3 else {
                dumpHeader(from: buffer)
                return .uncompleted
            }
            
            let byte0: UInt32 = (numericCast(pointer[0]) as UInt32).littleEndian
            let byte1: UInt32 = (numericCast(pointer[1]) as UInt32).littleEndian << 8
            let byte2: UInt32 = (numericCast(pointer[2]) as UInt32).littleEndian << 16
            
            let payloadSize = numericCast(byte0 | byte1 | byte2) as Int
            
            // sequenceID + payload
            let fullPacketSize = 1 &+ payloadSize
            
            if buffer.count < fullPacketSize {
                dumpPayload(
                    size: payloadSize,
                    from: ByteBuffer(start: pointer.advanced(by: 3), count: buffer.count - 3)
                )
                
                return .uncompleted
            } else {
                return .completed(
                    consuming: 3 &+ fullPacketSize,
                    result: Packet(payload:
                        ByteBuffer(start: pointer.advanced(by: 3), count: fullPacketSize)
                    )
                )
            }
        } else {
            switch parseHeader(from: buffer) {
            case .uncompleted:
                return .uncompleted
            case .completed(let consumed, let header):
                let fullPacketSize = 1 &+ header
                
                if buffer.count < fullPacketSize {
                    dumpPayload(
                        size: fullPacketSize,
                        from: ByteBuffer(start: pointer.advanced(by: consumed), count: buffer.count - consumed)
                    )
                    
                    return .uncompleted
                } else {
                    return .completed(
                        consuming: consumed &+ fullPacketSize,
                        result: Packet(payload:
                            ByteBuffer(start: pointer.advanced(by: consumed), count: fullPacketSize)
                        )
                    )
                }
            }
        }
    }
    
    private func dumpHeader(from buffer: ByteBuffer) {
        guard headerBytes.count &+ buffer.count < 3 else {
            fatalError("Dumping MySQL packet header which is large enough to parse")
        }
        
        let pointer = buffer.baseAddress!
        
        // at least 4 packet bytes for new packets
        if buffer.count == 0 {
            return
        }
        
        switch buffer.count {
        case 1:
            headerBytes += [
                pointer[0]
            ]
        case 2:
            headerBytes += [
                pointer[0], pointer[1]
            ]
        default:
            headerBytes += [
                pointer[0], pointer[1], pointer[1]
            ]
        }
    }
    
    private func dumpPayload(size: Int, from buffer: ByteBuffer) {
        // dump payload inside packet
        // Build a buffer size, we need to copy this since it's not complete
        let bufferPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        let buffer = MutableByteBuffer(start: bufferPointer, count: size)
        
        let containing = min(buffer.count, size)
        memcpy(bufferPointer, buffer.baseAddress!, containing)
        
        self.partiallyParsed = (buffer, containing)
    }
    
    /// Do not call this function is the headerBytes size == 0
    private func parseHeader(from buffer: ByteBuffer) -> ParsingState<Int> {
        guard headerBytes.count > 0 else {
            fatalError("Incorrect usage of MySQL packet header parsing")
        }
        
        guard buffer.count &+ headerBytes.count >= 3 else {
            dumpHeader(from: buffer)
            return .uncompleted
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
            
            headerBytes = []
        case 2:
            byte0 = (numericCast(headerBytes[0]) as UInt32).littleEndian
            byte1 = (numericCast(headerBytes[1]) as UInt32).littleEndian << 8
            
            byte2 = (numericCast(pointer[0]) as UInt32).littleEndian << 16
            consumed = 1
            
            headerBytes = []
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

