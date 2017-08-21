import Core

struct Field {
    let catalog: String
    let database: String
    let table: String
    let originalTable: String
    let name: String
    let originalName: String
    let charSet: UInt8
    let collation: UInt8
    let length: UInt32
    let fieldType: UInt8
    let flags: UInt16
    let decimals: UInt8
}

struct Row {
    
}

class ResultsBuilder : Stream {
    func inputStream(_ input: Packet) {
        do {
            guard let header = self.header else {
                let parser = Parser(packet: input)
                self.header = try parser.parseLenEnc()
                return
            }
            
            guard columns.count == header else {
                parseColumns(from: input, amount: header)
                return
            }
            
            parseRow(from: input)
            
            if endOfResults {
                self.outputStream?(Results(fields: self.columns, rows: self.rows))
            }
        } catch {
            errorStream?(error)
        }
    }
    
    func parseColumns(from packet: Packet, amount: UInt64) {
        if amount == 0 {
            self.columns = []
        }
        
        // EOF
        if packet.isResponse {
            do {
                switch try packet.parseResponse(mysql41: connection?.mysql41 == true) {
                case .error(let error):
                    self.errorStream?(error)
                    self.reset()
                    return
                case .ok(_):
                    fallthrough
                case .eof(_):
                    guard amount == columns.count else {
                        self.errorStream?(MySQLError.invalidPacket)
                        self.reset()
                        return
                    }
                }
            } catch {
                self.errorStream?(MySQLError.invalidPacket)
                self.reset()
                return
            }
        }
        
        let parser = Parser(packet: packet)
        
        do {
            let catalog = try parser.parseLenEncString()
            let database = try parser.parseLenEncString()
            let table = try parser.parseLenEncString()
            let originalTable = try parser.parseLenEncString()
            let name = try parser.parseLenEncString()
            let originalName = try parser.parseLenEncString()
            
            parser.position += 1
            
            let charSet = try parser.byte()
            let collation = try parser.byte()
            
            let length = try parser.parseUInt32()
            
            let fieldType = try parser.byte()
            let flags = try parser.parseUInt16()
            let decimals = try parser.byte()
            
            let field = Field(catalog: catalog,
                              database: database,
                              table: table,
                              originalTable: originalTable,
                              name: name,
                              originalName: originalName,
                              charSet: charSet,
                              collation: collation,
                              length: length,
                              fieldType: fieldType,
                              flags: flags,
                              decimals: decimals)
            
            self.columns.append(field)
        } catch {
            self.errorStream?(MySQLError.invalidPacket)
            self.reset()
            return
        }
    }
    
    var endOfResults = false
    fileprivate let serverMoreResultsExists: UInt16 = 0x0008
    
    func parseRow(from packet: Packet) {
        do {
            if packet.payload.count == 5, packet.payload[0] == 0xfe {
                let parser = Parser(packet: packet)
                let flags = try parser.parseUInt16()
                self.endOfResults = (flags & serverMoreResultsExists) == 0
                return
            }
        } catch {
            self.errorStream?(error)
            self.reset()
            return
        }
        
        print(packet.payload)
    }
    
    func reset() {
        self.header = nil
        self.columns = []
    }
    
    weak var connection: Connection?
    var header: UInt64?
    var columns = [Field]()
    var rows = [Row]()
    
    var outputStream: ((Results) -> ())?
    
    var errorStream: BaseStream.ErrorHandler?
    
    typealias Input = Packet
    typealias Output = Results
}

class Results {
    var fields: [Field]
    var rows: [Row]
    
    init(fields: [Field], rows: [Row]) {
        self.fields = fields
        self.rows = rows
    }
}
