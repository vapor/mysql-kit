import Foundation
import MySQLNIO
import NIOFoundationCompat

extension Optional: MySQLDataConvertible where Wrapped: MySQLDataConvertible {
    public init?(mysqlData: MySQLData) {
        if mysqlData.buffer != nil {
            guard let value = Wrapped.init(mysqlData: mysqlData) else {
                return nil
            }
            self = .some(value)
        } else {
            self = .none
        }
    }
    
    public var mysqlData: MySQLData? {
        return self.flatMap(\.mysqlData)
    }
}

public struct MySQLDataDecoder {
    let json: JSONDecoder

    public init(json: JSONDecoder = .init()) {
        self.json = json
    }
    
    public func decode<T>(_ type: T.Type, from data: MySQLData) throws -> T
        where T: Decodable
    {
        // If `T` can be converted directly, just do so.
        if let convertible = T.self as? MySQLDataConvertible.Type {
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
            // handle "box" types such as `RawRepresentable` enums and `Optional` (if Optional didn't already directly
            // conform), but still allow falling back to JSON.
            do {
                return try T.init(from: GiftBoxUnwrapDecoder(decoder: self, data: data))
            } catch DecodingError.dataCorrupted {
                // Couldn't unwrap it either. Fall back to attempting a JSON decode.
                return try self.json.decode(T.self, from: data.buffer!)
            }
        }
    }
    
    private final class GiftBoxUnwrapDecoder: Decoder, SingleValueDecodingContainer {
        var codingPath: [CodingKey] { [] }
        var userInfo: [CodingUserInfoKey : Any] { [:] }

        let dataDecoder: MySQLDataDecoder
        let data: MySQLData
        
        init(decoder: MySQLDataDecoder, data: MySQLData) {
            self.dataDecoder = decoder
            self.data = data
        }
        
        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Array containers must be JSON-encoded"))
        }
        
        func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Dictionary containers must be JSON-encoded"))
        }
        
        func singleValueContainer() throws -> SingleValueDecodingContainer {
            return self
        }

        func decodeNil() -> Bool {
            self.data.buffer == nil
        }

        func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            // Recurse back into the data decoder, don't repeat its logic here.
            return try self.dataDecoder.decode(T.self, from: self.data)
        }
    }
}
