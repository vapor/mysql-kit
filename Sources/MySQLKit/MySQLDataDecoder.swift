import Foundation

private struct DecoderUnwrapper: Decodable {
    let decoder: Decoder
    init(from decoder: Decoder) {
        self.decoder = decoder
    }
}

private struct Wrapper<D>: Decodable where D: Decodable {
    var value: D

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(D.self)
    }
}

extension MySQLData {
    var data: Data? {
        self.buffer.flatMap {
            .init($0.readableBytesView)
        }
    }
}

public struct MySQLDataDecoder {
    public init() {}
    
    public func decode<T>(_ type: T.Type, from data: MySQLData) throws -> T
        where T: Decodable
    {
        if let convertible = T.self as? MySQLDataConvertible.Type {
            return convertible.init(mysqlData: data)! as! T
        } else {
            return try T.init(from: _Decoder(data: data))
        }
    }
    
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
            try JSONDecoder()
                .decode(DecoderUnwrapper.self, from: self.data.data!)
                .decoder.unkeyedContainer()
        }
        
        func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
            where Key : CodingKey
        {
            try JSONDecoder()
                .decode(DecoderUnwrapper.self, from: self.data.data!)
                .decoder.container(keyedBy: Key.self)
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
                    throw DecodingError.typeMismatch(T.self, DecodingError.Context.init(
                        codingPath: self.codingPath,
                        debugDescription: "Could not convert from MySQL data: \(T.self)"
                    ))
                }
                return value as! T
            } else {
                return try MySQLDataDecoder().decode(T.self, from: self.decoder.data)
            }
        }
    }
}
