import Foundation

extension Packet {
    /// Returns `true` if this could be a text-protocol response
    var isTextProtocolResponse: Bool {
        return payload.count > 0 && (payload[0] == 0xff || payload[0] == 0xfe || payload[0] == 0x00)
    }
    
    func parseBinaryOK() throws -> (UInt64, UInt64)? {
        if self.payload.count == 5 {
            return nil
        }
        
        var parser = Parser(packet: self)
        let byte = try parser.byte()
        
        if byte == 0x00 {
            return (try parser.parseLenEnc(), try parser.parseLenEnc())
        } else if byte == 0xfe {
            return (try parser.parseLenEnc(), try parser.parseLenEnc())
        } else if byte == 0xff {
            throw MySQLError(packet: self)
        }
        
        return nil
    }
}
