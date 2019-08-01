import Foundation

#warning("TODO: move to codable kit")
struct DecoderUnwrapper: Decodable {
    let decoder: Decoder
    init(from decoder: Decoder) {
        self.decoder = decoder
    }
}

public struct MySQLDataDecoder {
    public init() {}
    
    public func decode<T>(_ type: T.Type, from data: MySQLData) throws -> T
        where T: Decodable
    {
        return try T.init(from: _Decoder(data: data))
    }
    
    #warning("TODO: finish implementing")
    
    private final class _Decoder: Decoder {
        var codingPath: [CodingKey] {
            return []
        }
        
        var userInfo: [CodingUserInfoKey : Any] {
            return [:]
        }
        
        let data: MySQLData
        init(data: MySQLData) {
            self.data = data
        }
        
        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            fatalError()
        }
        
        func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
            #warning("TODO: use NIOFoundationCompat")
            var buffer = self.data.buffer!
            let data = buffer.readBytes(length: buffer.readableBytes)!
            let unwrapper = try JSONDecoder().decode(DecoderUnwrapper.self, from: Data(data))
            return try unwrapper.decoder.container(keyedBy: Key.self)
        }
        
        func singleValueContainer() throws -> SingleValueDecodingContainer {
            return _SingleValueDecoder(self)
        }
    }
    
    private struct _SingleValueDecoder: SingleValueDecodingContainer {
        var codingPath: [CodingKey] {
            return self.decoder.codingPath
        }
        let decoder: _Decoder
        init(_ decoder: _Decoder) {
            self.decoder = decoder
        }
        
        func decodeNil() -> Bool {
            return self.decoder.data.buffer == nil
        }
        
        func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            if let convertible = T.self as? MySQLDataConvertible.Type {
                guard let value = convertible.init(mysqlData: self.decoder.data) else {
                    throw DecodingError.typeMismatch(convertible, DecodingError.Context.init(
                        codingPath: self.codingPath,
                        debugDescription: "Could not convert from MySQL data: \(T.self)"
                    ))
                }
                return value as! T
            } else {
                return try T.init(from: self.decoder)
            }
        }
    }
}
