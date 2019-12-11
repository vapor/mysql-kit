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
            _UnkeyedEncoder(self)
        }
        
        func singleValueContainer() -> SingleValueEncodingContainer {
            _SingleValueEncoder(self)
        }
    }
    
    struct DoJSON: Error {}

    private struct _UnkeyedEncoder: UnkeyedEncodingContainer {
        var codingPath: [CodingKey] {
            self.encoder.codingPath
        }
        var count: Int {
            0
        }

        let encoder: _Encoder
        init(_ encoder: _Encoder) {
            self.encoder = encoder
        }


        mutating func encodeNil() throws {
            throw DoJSON()
        }

        mutating func encode<T>(_ value: T) throws
            where T : Encodable
        {
            throw DoJSON()
        }

        mutating func nestedContainer<NestedKey>(
            keyedBy keyType: NestedKey.Type
        ) -> KeyedEncodingContainer<NestedKey>
            where NestedKey : CodingKey
        {
            self.encoder.container(keyedBy: NestedKey.self)
        }

        mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            self.encoder.unkeyedContainer()
        }

        mutating func superEncoder() -> Encoder {
            self.encoder
        }
    }
    
    private struct _KeyedValueEncoder<Key>: KeyedEncodingContainerProtocol where Key: CodingKey {
        var codingPath: [CodingKey] {
            return self.encoder.codingPath
        }
        
        let encoder: _Encoder
        init(_ encoder: _Encoder) {
            self.encoder = encoder
        }
        
        mutating func encodeNil(forKey key: Key) throws {
            throw DoJSON()
        }
        
        mutating func encode<T>(_ value: T, forKey key: Key) throws
            where T : Encodable
        {
            throw DoJSON()
        }
        
        mutating func nestedContainer<NestedKey>(
            keyedBy keyType: NestedKey.Type,
            forKey key: Key
        ) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
            self.encoder.container(keyedBy: NestedKey.self)
        }
        
        mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            self.encoder.unkeyedContainer()
        }
        
        mutating func superEncoder() -> Encoder {
            self.encoder
        }
        
        mutating func superEncoder(forKey key: Key) -> Encoder {
            self.encoder
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
