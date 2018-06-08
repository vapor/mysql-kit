struct MySQLRowDecoder {
    init() { }
    
    func decode<D>(_ type: D.Type, from row: [MySQLColumn: MySQLData], table: String? = nil) throws -> D
        where D: Decodable
    {
        return try D(from: _Decoder(row: row, table: table))
    }
    
    // MARK: Private
    
    private struct _Decoder: Decoder {
        let codingPath: [CodingKey] = []
        var userInfo: [CodingUserInfoKey: Any] = [:]
        let row: [MySQLColumn: MySQLData]
        let table: String?
        
        init(row: [MySQLColumn: MySQLData], table: String?) {
            self.row = row
            self.table = table
        }
        
        func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
            return .init(_KeyedDecodingContainer(row: row, table: table))
        }
        
        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            fatalError()
        }
        
        func singleValueContainer() throws -> SingleValueDecodingContainer {
            fatalError()
        }
    }
    
    private struct _KeyedDecodingContainer<Key>: KeyedDecodingContainerProtocol where Key: CodingKey {
        let allKeys: [Key]
        let codingPath: [CodingKey] = []
        let row: [MySQLColumn: MySQLData]
        let table: String?
        
        init(row: [MySQLColumn: MySQLData], table: String?) {
            self.row = row
            self.table = table
            self.allKeys = row.keys.compactMap { col in
                if table == nil || col.table == table || col.table == nil {
                    return col.name
                } else {
                    return nil
                }
            }.compactMap(Key.init(stringValue:))
        }
        
        func contains(_ key: Key) -> Bool {
            return allKeys.contains { $0.stringValue == key.stringValue }
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            guard let data = row.firstValue(forColumn: key.stringValue, inTable: table) else {
                return true
            }
            switch data {
            case .null: return true
            default: return false
            }
        }
        
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
            guard let data = row.firstValue(forColumn: key.stringValue, inTable: table) else {
                throw DecodingError.valueNotFound(T.self, .init(codingPath: codingPath + [key], debugDescription: "Could not decode \(T.self)."))
            }
            return try MySQLDataDecoder().decode(T.self, from: data)
        }
        
        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            fatalError()
        }
        
        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            fatalError()
        }
        
        func superDecoder() throws -> Decoder {
            fatalError()
        }
        
        func superDecoder(forKey key: Key) throws -> Decoder {
            fatalError()
        }
    }
}

