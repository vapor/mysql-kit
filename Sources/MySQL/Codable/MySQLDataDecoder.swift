struct MySQLDataDecoder {
    init() { }
    
    public func decode<D>(_ type: D.Type, from data: MySQLData) throws -> D where D: Decodable {
        if let convertible = type as? MySQLDataConvertible.Type {
            return try convertible.convertFromMySQLData(data) as! D
        }
        return try D(from: _Decoder(data: data))
    }
    
    // MARK: Private
    
    private struct _Decoder: Decoder {
        let codingPath: [CodingKey] = []
        var userInfo: [CodingUserInfoKey: Any] = [:]
        let data: MySQLData
        
        init(data: MySQLData) {
            self.data = data
        }
        
        struct DecoderUnwrapper: Decodable {
            let decoder: Decoder
            init(from decoder: Decoder) throws {
                self.decoder = decoder
            }
        }
        
        func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
            return try jsonDecoder().container(keyedBy: Key.self)
        }
        
        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            return try jsonDecoder().unkeyedContainer()
        }
        
        private func jsonDecoder() throws -> Decoder {
            let json: Data
            switch data.storage {
            case .binary(let binary):
                switch binary.storage {
                case .string(let data): json = data
                default: throw MySQLError(identifier: "json", reason: "Could not decode JSON.")
                }
            case .text(let data): json = data ?? Data()
            }
            let unwrapper = try JSONDecoder().decode(DecoderUnwrapper.self, from: json)
            return unwrapper.decoder
        }
        
        func singleValueContainer() throws -> SingleValueDecodingContainer {
            return _SingleValueDecodingContainer(data: data)
        }
    }
    
    private struct _SingleValueDecodingContainer: SingleValueDecodingContainer {
        let codingPath: [CodingKey] = []
        let data: MySQLData
        
        init(data: MySQLData) {
            self.data = data
        }
        
        public func decodeNil() -> Bool {
            switch data {
            case .null: return true
            default: return false
            }
        }
        
        func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            guard let convertible = type as? MySQLDataConvertible.Type else {
                return try T(from: _Decoder(data: data))
            }
            return try convertible.convertFromMySQLData(data) as! T
        }
    }
}
