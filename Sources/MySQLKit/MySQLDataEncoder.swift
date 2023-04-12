import Foundation
import MySQLNIO

public struct MySQLDataEncoder {
    let json: JSONEncoder

    public init(json: JSONEncoder = .init()) {
        self.json = json
    }
    
    public func encode(_ value: Encodable) throws -> MySQLData {
        if let custom = value as? MySQLDataConvertible, let data = custom.mysqlData {
            return data
        } else {
            let encoder = _Encoder(parent: self)
            do {
                try value.encode(to: encoder)
                if let value = encoder.value {
                    return value
                } else {
                    throw _Encoder.NonScalarValueSentinel()
                }
            } catch is _Encoder.NonScalarValueSentinel {
                var buffer = ByteBufferAllocator().buffer(capacity: 0)
#if swift(<5.7)
                struct _Wrapper: Encodable {
                    let encodable: Encodable
                    init(_ encodable: Encodable) { self.encodable = encodable }
                    func encode(to encoder: Encoder) throws { try self.encodable.encode(to: encoder) }
                }
                try buffer.writeBytes(self.json.encode(_Wrapper(value))) // Swift <5.7 will complain that "Encodable does not conform to Encodable" without the wrapper
#else
                try buffer.writeBytes(self.json.encode(value))
#endif
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
        struct NonScalarValueSentinel: Error {}

        var userInfo: [CodingUserInfoKey : Any] { [:] }; var codingPath: [CodingKey] { [] }
        var parent: MySQLDataEncoder, value: MySQLData?
        
        init(parent: MySQLDataEncoder) { self.parent = parent }
        func container<K: CodingKey>(keyedBy: K.Type) -> KeyedEncodingContainer<K> { .init(_FailingKeyedContainer()) }
        func unkeyedContainer() -> UnkeyedEncodingContainer { _TaintedEncoder() }
        func singleValueContainer() -> SingleValueEncodingContainer {
            precondition(self.value == nil, "Requested multiple containers from the same encoder.")
            return _SingleValueContainer(encoder: self)
        }
        
        struct _SingleValueContainer: SingleValueEncodingContainer {
            let encoder: _Encoder; var codingPath: [CodingKey] { self.encoder.codingPath }
            func encodeNil() throws { self.encoder.value = .null }
            func encode<T: Encodable>(_ value: T) throws { self.encoder.value = try self.encoder.parent.encode(value) }
        }
        
        /// This pair of types is only necessary because we can't directly throw an error from various Encoder and
        /// encoding container methods. We define duplicate types rather than the old implementation's use of a
        /// no-action keyed container because it can save a significant amount of time otherwise spent uselessly calling
        /// nested methods in some cases.
        struct _TaintedEncoder: Encoder, UnkeyedEncodingContainer, SingleValueEncodingContainer {
            var userInfo: [CodingUserInfoKey : Any] { [:] }; var codingPath: [CodingKey] { [] }; var count: Int { 0 }
            func container<K: CodingKey>(keyedBy: K.Type) -> KeyedEncodingContainer<K> { .init(_FailingKeyedContainer()) }
            func nestedContainer<K: CodingKey>(keyedBy: K.Type) -> KeyedEncodingContainer<K> { .init(_FailingKeyedContainer()) }
            func unkeyedContainer() -> UnkeyedEncodingContainer { self }
            func nestedUnkeyedContainer() -> UnkeyedEncodingContainer { self }
            func singleValueContainer() -> SingleValueEncodingContainer { self }
            func superEncoder() -> Encoder { self }
            func encodeNil() throws { throw NonScalarValueSentinel() }
            func encode<T: Encodable>(_: T) throws { throw NonScalarValueSentinel() }
        }
        struct _FailingKeyedContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
            var codingPath: [CodingKey] { [] }
            func encodeNil(forKey: K) throws { throw NonScalarValueSentinel() }
            func encode<T: Encodable>(_: T, forKey: K) throws { throw NonScalarValueSentinel() }
            func nestedContainer<NK: CodingKey>(keyedBy: NK.Type, forKey: K) -> KeyedEncodingContainer<NK> { .init(_FailingKeyedContainer<NK>()) }
            func nestedUnkeyedContainer(forKey: K) -> UnkeyedEncodingContainer { _TaintedEncoder() }
            func superEncoder() -> Encoder { _TaintedEncoder() }
            func superEncoder(forKey: K) -> Encoder { _TaintedEncoder() }
        }
    }
}
