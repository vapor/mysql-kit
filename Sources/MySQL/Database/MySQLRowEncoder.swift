import Foundation

/// Encodes `Encodable` entities to MySQL rows (`[MySQLColumn: MySQLData]`)
public final class MySQLRowEncoder {
    /// Creates a new `MySQLRowEncoder`
    public init() { }

    /// Encodes the supplied `Encodable` item to a MySQL row.
    // fixme: make this generic
    public func encode(_ encodable: Encodable) throws -> [MySQLColumn: MySQLData] {
        let encoder = _MySQLRowEncoder()
        try encodable.encode(to: encoder)
        var results: [MySQLColumn: MySQLData] = [:]
        for (name, data) in encoder.data {
            let col = MySQLColumn(table: nil, name: name)
            results[col] = data
        }
        return results
    }
}

/// MARK: Private

fileprivate final class _MySQLRowEncoder: Encoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey : Any]
    var data: [String: MySQLData]
    init() {
        self.codingPath = []
        self.userInfo = [:]
        self.data = [:]
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        let container = MySQLRowKeyedEncodingContainer<Key>(encoder: self)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        unsupported()
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        unsupported()
    }

}

private func unsupported() -> Never {
    fatalError("""
    MySQL rows only support a flat, keyed structure `[String: T]`.

    Query data must be an encodable dictionary, struct, or class.

    You can also conform nested types to `MySQLJSONType`. (Nested types must be `MySQLDataConvertible`.)
    """)
}

fileprivate struct MySQLRowKeyedEncodingContainer<K>: KeyedEncodingContainerProtocol
    where K: CodingKey
{
    var codingPath: [CodingKey]
    let encoder: _MySQLRowEncoder
    init(encoder: _MySQLRowEncoder) {
        self.encoder = encoder
        self.codingPath = []
    }

    mutating func encodeNil(forKey key: K) throws { encoder.data[key.stringValue] = .null }
    mutating func encode(_ value: Bool, forKey key: K) throws { encoder.data[key.stringValue] = try value.convertToMySQLData() }
    mutating func encode(_ value: Int, forKey key: K) throws { encoder.data[key.stringValue] = try value.convertToMySQLData() }
    mutating func encode(_ value: Int16, forKey key: K) throws { encoder.data[key.stringValue] = try value.convertToMySQLData() }
    mutating func encode(_ value: Int32, forKey key: K) throws { encoder.data[key.stringValue] = try value.convertToMySQLData() }
    mutating func encode(_ value: Int64, forKey key: K) throws { encoder.data[key.stringValue] = try value.convertToMySQLData() }
    mutating func encode(_ value: UInt, forKey key: K) throws { encoder.data[key.stringValue] = try value.convertToMySQLData() }
    mutating func encode(_ value: UInt8, forKey key: K) throws { encoder.data[key.stringValue] = try value.convertToMySQLData() }
    mutating func encode(_ value: UInt16, forKey key: K) throws { encoder.data[key.stringValue] = try value.convertToMySQLData() }
    mutating func encode(_ value: UInt32, forKey key: K) throws { encoder.data[key.stringValue] = try value.convertToMySQLData() }
    mutating func encode(_ value: UInt64, forKey key: K) throws { encoder.data[key.stringValue] = try value.convertToMySQLData() }
    mutating func encode(_ value: Double, forKey key: K) throws { encoder.data[key.stringValue] = try value.convertToMySQLData() }
    mutating func encode(_ value: Float, forKey key: K) throws { encoder.data[key.stringValue] = try value.convertToMySQLData() }
    mutating func encode(_ value: String, forKey key: K) throws { encoder.data[key.stringValue] = try value.convertToMySQLData() }
    mutating func superEncoder() -> Encoder { return encoder }
    mutating func superEncoder(forKey key: K) -> Encoder { return encoder }
    
    mutating func encode<T>(_ value: T, forKey key: K) throws where T: Encodable {
        guard let convertible = value as? MySQLDataConvertible else {
            let type = Swift.type(of: value)
            throw MySQLError(
                identifier: "convertible",
                reason: "Unsupported encodable type: \(type)",
                suggestedFixes: [
                    "Conform \(type) to `MySQLDataConvertible`"
                ],
                source: .capture()
            )
        }
        encoder.data[key.stringValue] = try convertible.convertToMySQLData()
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        return encoder.container(keyedBy: NestedKey.self)
    }

    mutating func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        return encoder.unkeyedContainer()
    }
}

