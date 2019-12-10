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

private struct DoJSON: Error { }

public struct MySQLDataDecoder {
    public init() {}
    
    public func decode<T>(_ type: T.Type, from data: MySQLData) throws -> T
        where T: Decodable
    {
        do {
            return try Wrapper<T>.init(from: _Decoder(data: data)).value
        } catch is DoJSON {
            guard let value = try data.json(as: T.self) else {
                throw DecodingError.typeMismatch(T.self, DecodingError.Context.init(
                    codingPath: [],
                    debugDescription: "Could not convert from MySQL data: \(T.self)"
                ))
            }
            return value
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
            throw DoJSON()
        }
        
        func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
            where Key : CodingKey
        {
            throw DoJSON()
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
                return try T.init(from: self.decoder)
            }
        }
    }
}
