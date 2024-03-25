import Foundation
import MySQLNIO
import NIOFoundationCompat
@_spi(CodableUtilities) import SQLKit

public struct MySQLDataDecoder: Sendable {
    let json: JSONDecoder

    public init(json: JSONDecoder = .init()) {
        self.json = json
    }
    
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
                return try self.json.decode(T.self, from: data.buffer ?? .init())
            }
        }
    }
    
    private final class NestedSingleValueUnwrappingDecoder: Decoder, SingleValueDecodingContainer {
        var codingPath: [any CodingKey] { [] }
        var userInfo: [CodingUserInfoKey: Any] { [:] }

        let dataDecoder: MySQLDataDecoder
        let data: MySQLData
        
        init(decoder: MySQLDataDecoder, data: MySQLData) {
            self.dataDecoder = decoder
            self.data = data
        }
        
        func container<Key: CodingKey>(keyedBy: Key.Type) throws -> KeyedDecodingContainer<Key> {
            throw .invalid(at: self.codingPath)
        }
        
        func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
            throw .invalid(at: self.codingPath)
        }
        
        func singleValueContainer() throws -> any SingleValueDecodingContainer {
            self
        }

        func decodeNil() -> Bool {
            self.data.type == .null || self.data.buffer == nil
        }

        func decode<T: Decodable>(_: T.Type) throws -> T {
            try self.dataDecoder.decode(T.self, from: self.data)
        }
    }
}
