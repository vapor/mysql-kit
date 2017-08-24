class RowDecoder : Decoder {
    let packet: Packet
    
    init(packet: Packet, columns: [Field]) throws {
        self.packet = packet
        
    }
    
    var codingPath: [CodingKey] = []
    
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        throw MySQLError.unsupported
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw MySQLError.unsupported
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw MySQLError.unsupported
    }
}

