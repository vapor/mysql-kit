public struct MySQLQueryEncoder {
    public init() { }
    
    public func encode<E>(_ value: E) throws -> [String: MySQLQuery.Expression]
        where E: Encodable
    {
        let encoder = _Encoder()
        try value.encode(to: encoder)
        return encoder.row
    }
    
    // MARK: Private
    
    private final class _Encoder: Encoder {
        let codingPath: [CodingKey] = []
        var userInfo: [CodingUserInfoKey: Any] = [:]
        var row: [String: MySQLQuery.Expression]
        
        init() {
            self.row = [:]
        }
        
        func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
            return .init(_KeyedEncodingContainer(encoder: self))
        }
        
        func unkeyedContainer() -> UnkeyedEncodingContainer {
            fatalError()
        }
        
        func singleValueContainer() -> SingleValueEncodingContainer {
            fatalError()
        }
    }
    
    private struct _KeyedEncodingContainer<Key>: KeyedEncodingContainerProtocol where Key: CodingKey {
        let codingPath: [CodingKey] = []
        let encoder: _Encoder
        init(encoder: _Encoder) {
            self.encoder = encoder
        }
        
        mutating func encodeNil(forKey key: Key) throws {
            encoder.row[key.stringValue] = .literal(.null)
        }
        
        mutating func encode<T>(_ encodable: T, forKey key: Key) where T : Encodable {
            encoder.row[key.stringValue] = MySQLQueryExpressionEncoder().encode(encodable)
        }
        
        mutating func _encodeIfPresent<T>(_ value: T?, forKey key: Key) throws where T : Encodable {
            if let value = value {
                encode(value, forKey: key)
            } else {
                try encodeNil(forKey: key)
            }
        }
        
        mutating func encodeIfPresent<T>(_ value: T?, forKey key: Key) throws where T : Encodable { try _encodeIfPresent(value, forKey: key)}
        mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws { try _encodeIfPresent(value, forKey: key) }
        mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws { try _encodeIfPresent(value, forKey: key) }
        mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws { try _encodeIfPresent(value, forKey: key) }
        mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws { try _encodeIfPresent(value, forKey: key) }
        mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws { try _encodeIfPresent(value, forKey: key) }
        mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws { try _encodeIfPresent(value, forKey: key) }
        mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws { try _encodeIfPresent(value, forKey: key) }
        mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws { try _encodeIfPresent(value, forKey: key) }
        mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws { try _encodeIfPresent(value, forKey: key) }
        mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws { try _encodeIfPresent(value, forKey: key) }
        mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws { try _encodeIfPresent(value, forKey: key) }
        mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws { try _encodeIfPresent(value, forKey: key) }
        mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws { try _encodeIfPresent(value, forKey: key) }
        
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
}
