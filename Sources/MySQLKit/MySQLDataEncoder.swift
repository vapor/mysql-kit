import Foundation

public struct MySQLDataEncoder {
    let json: JSONEncoder

    public init(json: JSONEncoder = .init()) {
        self.json = json
    }
    
    public func encode(_ value: Encodable) throws -> MySQLData {
        if let custom = value as? MySQLDataConvertible, let data = custom.mysqlData {
            return data
        } else {
            let encoder = _Encoder()
            try value.encode(to: encoder)
            if let data = encoder.data {
                return data
            } else {
                var buffer = ByteBufferAllocator().buffer(capacity: 0)
                try buffer.writeBytes(self.json.encode(_Wrapper(value)))
                return MySQLData(
                    type: .string,
                    format: .text,
                    buffer: buffer,
                    isUnsigned: true
                )
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
        var data: MySQLData?
        init() {

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


        mutating func encodeNil() throws { }

        mutating func encode<T>(_ value: T) throws
            where T : Encodable
        { }

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
        
        mutating func encodeNil(forKey key: Key) throws { }
        
        mutating func encode<T>(_ value: T, forKey key: Key) throws
            where T : Encodable
        { }
        
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
                        debugDescription: "Could not encode \(T.self) to MySQL data: \(value)"
                    ))
                }
                self.encoder.data = data
            } else {
                try value.encode(to: self.encoder)
            }
        }
    }
}

struct _Wrapper: Encodable {
    let encodable: Encodable
    init(_ encodable: Encodable) {
        self.encodable = encodable
    }
    func encode(to encoder: Encoder) throws {
        try self.encodable.encode(to: encoder)
    }
}
