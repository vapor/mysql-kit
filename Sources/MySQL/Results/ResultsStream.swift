import Async

/// A stream of decoded rows related to a query
///
/// This API is currently internal so we don't break the public API when finalizing the "raw" row API
final class RowParser: TranslatingStream {
    enum RowStreamState {
        case headers, rows
    }
    
    /// See InputStream.Input
    typealias Input = Packet
    
    /// See OutputStream.Output
    typealias Output = Row
    
    typealias PacketOKSetter = ((UInt64, UInt64) -> ())
    
    /// Handles EOF
    typealias OnEOF = (UInt16) throws -> ()
    
    var state: RowStreamState
    
    /// A list of all fields' descriptions in this table
    var columns = [Field]()
    
    /// Used to indicate the amount of returned columns
    var columnCount: UInt64?
    
    /// If `true`, the server protocol version is for MySQL 4.1
    let mysql41: Bool
    
    /// Used to reserve capacity when parsing rows
    var reserveCapacity: Int? = nil
    
    /// If `true`, the results are using the binary protocols
    var binary: Bool
    
    var packetOKcallback: PacketOKSetter?
    
    /// Creates a new RowStream using the specified protocol (from MySQL 4.0 or 4.1) and optionally the binary protocol instead of text
    init(mysql41: Bool, binary: Bool, packetOKcallback: PacketOKSetter? = nil) {
        self.mysql41 = mysql41
        self.binary = binary
        self.packetOKcallback = packetOKcallback
        self.state = .headers
    }
    
    func translate(input: Packet) throws -> Future<TranslatingStreamResult<Row>> {
        // If the header (column count) is not yet set
        guard let columnCount = self.columnCount else {
            // Parse the column count
            var parser = Parser(packet: input)
            
            // Tries to parse the header count
            guard let columnCount = try? parser.parseLenEnc() else {
                if case .error(let error) = try input.parseResponse(mysql41: mysql41) {
                    throw error
                } else {
                    return Future(.closed)
                }
            }

            // No columns means that this is likely the success response of a binary INSERT/UPDATE/DELETE query
            if columnCount == 0 {
                if let (affectedRows, lastInsertID) = try input.parseBinaryOK() {
                    self.packetOKcallback?(affectedRows, lastInsertID)
                }
                
                return Future(.closed)
            }
            
            self.columnCount = columnCount
            
            return Future(.insufficient)
        }

        switch state {
        case .headers:
            // if the column count isn't met yet
            if columns.count == columnCount {
                return try row(from: input)
            } else {
                // Parse the next column
                try appendColumn(from: input)
                
                return Future(.insufficient)
            }
        case .rows:
            // Otherwise, parse the next row
            return try row(from: input)
        }
    }
    
    /// Parses a row from this packet, checks
    func row(from packet: Packet) throws -> Future<TranslatingStreamResult<Row>> {
        // If it's an error packet
        if packet.payload.count > 0,
            let pointer = packet.payload.baseAddress,
            pointer[0] == 0xff,
            let error = try packet.parseResponse(mysql41: self.mysql41).error
        {
            throw error
        }
        
        let row = try packet.parseRow(columns: columns, binary: binary, reserveCapacity: reserveCapacity)
        
        if reserveCapacity == nil {
            self.reserveCapacity = row.fields.count
        }
        
        return Future(.sufficient(row))
    }

    /// Parses the packet as a columm specification
    func appendColumn(from packet: Packet) throws {
        // Normal responses indicate an end of columns or an error
        if packet.isTextProtocolResponse {
            switch try packet.parseResponse(mysql41: mysql41) {
            case .error(let error):
                throw error
            case .ok(_):
                fallthrough
            case .eof(_):
                // If this is the end of the stream, stop
                return
            }
        }
        
        // Parse the column field definition
        let field = try packet.parseFieldDefinition()

        self.columns.append(field)
    }
}

extension MySQLStateMachine {
    func makeRowParser(binary: Bool) -> TranslatingStreamWrapper<RowParser> {
        return RowParser(mysql41: self.handshake!.mysql41, binary: binary).stream(on: worker)
    }
}

