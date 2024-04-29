import Foundation
import MySQLNIO
import NIOFoundationCompat
@_spi(CodableUtilities) import SQLKit

/// Translates `MySQLData` values received from the database into `Decodable` values.
///
/// Types which conform to `MySQLDataConvertible` are converted directly to the requested type. For other types,
/// an attempt is made to interpret the database value as JSON and decode the type from it.
public struct MySQLDataDecoder: Sendable {
    /// A wrapper to silence `Sendable` warnings for `JSONDecoder` when not on macOS.
    struct FakeSendable<T>: @unchecked Sendable { let value: T }
    
    /// The `JSONDecoder` used for decoding values that can't be directly converted.
    let json: FakeSendable<JSONDecoder>
    
    /// Initialize a ``MySQLDataDecoder`` with a JSON decoder.
    ///
    /// - Parameter json: A `JSONDecoder` to use for decoding types that can't be directly converted. Defaults
    ///   to an unconfigured decoder.
    public init(json: JSONDecoder = .init()) {
        self.json = .init(value: json)
    }
    
    /// Convert the given `MySQLData` into a value of type `T`, if possible.
    ///
    /// - Parameters:
    ///   - type: The desired result type.
    ///   - data: The data to decode.
    /// - Returns: The decoded value, if successful.
    public func decode<T: Decodable>(_ type: T.Type, from data: MySQLData) throws -> T {
        // If `T` can be converted directly, just do so.
        if let convertible = T.self as? any MySQLDataConvertible.Type {
            guard let value = convertible.init(mysqlData: data) else {
                throw DecodingError.typeMismatch(T.self, .init(
                    codingPath: [],
                    debugDescription: "Could not convert MySQL data to \(T.self): \(data)"
                ))
            }
            return value as! T
        } else {
            // Probably either a JSON array/object or an enum type not using @Enum. See if it can be "unwrapped" as a
            // single-value decoding container, since this is much faster than attempting a JSON decode; this will
            // handle "box" types such as `RawRepresentable` enums or fall back on JSON decoding if necessary.
            do {
                return try T.init(from: NestedSingleValueUnwrappingDecoder(decoder: self, data: data))
            } catch is SQLCodingError where [.blob, .json, .longBlob, .mediumBlob, .string, .tinyBlob, .varString, .varchar].contains(data.type) {
                // Couldn't unwrap it, but it's textual. Try decoding as JSON as a last ditch effort.
                return try self.json.value.decode(T.self, from: data.buffer ?? .init())
            }
        }
    }
    
    /// A trivial decoder for unwrapping types which decode as trivial single-value containers. This allows for
    /// correct handling of types such as `Optional` when they do not conform to `MySQLDataCovnertible`.
    private final class NestedSingleValueUnwrappingDecoder: Decoder, SingleValueDecodingContainer {
        // See `Decoder.codingPath` and `SingleValueDecodingContainer.codingPath`.
        var codingPath: [any CodingKey] { [] }
        
        // See `Decoder.userInfo`.
        var userInfo: [CodingUserInfoKey: Any] { [:] }

        /// The parent ``MySQLDataDecoder``.
        let dataDecoder: MySQLDataDecoder
        
        /// The data to decode.
        let data: MySQLData
        
        /// Create a new decoder with a ``MySQLDataDecoder`` and the data to decode.
        init(decoder: MySQLDataDecoder, data: MySQLData) {
            self.dataDecoder = decoder
            self.data = data
        }
        
        // See `Decoder.container(keyedBy:)`.
        func container<Key: CodingKey>(keyedBy: Key.Type) throws -> KeyedDecodingContainer<Key> {
            throw .invalid(at: self.codingPath)
        }
        
        // See `Decoder.unkeyedContainer()`.
        func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
            throw .invalid(at: self.codingPath)
        }
        
        // See `Decoder.singleValueContainer()`.
        func singleValueContainer() throws -> any SingleValueDecodingContainer {
            self
        }

        // See `SingleValueDecodingContainer.decodeNil()`.
        func decodeNil() -> Bool {
            self.data.type == .null || self.data.buffer == nil
        }

        // See `SingleValueDecodingContainer.decode(_:)`.
        func decode<T: Decodable>(_: T.Type) throws -> T {
            try self.dataDecoder.decode(T.self, from: self.data)
        }
    }
}
