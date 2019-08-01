import Foundation

public struct MySQLDataEncoder {
    public init() { }
    
    public func encode(_ type: Encodable) throws -> MySQLData {
        if let custom = type as? MySQLDataConvertible {
            return custom.mysqlData!
        } else {
            do {
                let encoder = _Encoder()
                try type.encode(to: encoder)
                return encoder.data
            } catch is DoJSON {
                return try MySQLData(json: type)
            }
        }
    }
    
    private final class _Encoder: Encoder {
        var codingPath: [CodingKey] {
            return []
        }
        
        var userInfo: [CodingUserInfoKey : Any] {
            return [:]
        }
        var data: MySQLData
        init() {
            self.data = .null
        }
        
        func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
            return .init(_KeyedValueEncoder(self))
        }
        
        func unkeyedContainer() -> UnkeyedEncodingContainer {
            fatalError()
        }
        
        func singleValueContainer() -> SingleValueEncodingContainer {
            return _SingleValueEncoder(self)
        }
    }
    
    struct DoJSON: Error {}
    
    private struct _KeyedValueEncoder<Key>: KeyedEncodingContainerProtocol where Key: CodingKey {
        var codingPath: [CodingKey] {
            return self.encoder.codingPath
        }
        
        let encoder: _Encoder
        init(_ encoder: _Encoder) {
            self.encoder = encoder
        }
        
        mutating func encodeNil(forKey key: Key) throws {
            fatalError()
        }
        
        mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
            throw DoJSON()
        }
        
        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
            fatalError()
        }
        
        mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            fatalError()
        }
        
        mutating func superEncoder() -> Encoder {
            fatalError()
        }
        
        mutating func superEncoder(forKey key: Key) -> Encoder {
            fatalError()
        }
    }
    
    
    private struct _SingleValueEncoder: SingleValueEncodingContainer {
        var codingPath: [CodingKey] {
            return self.encoder.codingPath
        }
        
        let encoder: _Encoder
        init(_ encoder: _Encoder) {
            self.encoder = encoder
        }
        
        mutating func encodeNil() throws {
            self.encoder.data = MySQLData.null
        }
        
        mutating func encode<T>(_ value: T) throws where T : Encodable {
            if let convertible = value as? MySQLDataConvertible {
                guard let data = convertible.mysqlData else {
                    throw EncodingError.invalidValue(convertible, EncodingError.Context(
                        codingPath: self.codingPath,
                        debugDescription: "Could not convert value of type \(T.self)"
                    ))
                }
                self.encoder.data = data
            } else {
                try value.encode(to: self.encoder)
            }
        }
    }
}
