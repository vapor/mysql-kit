import Foundation
import MySQLNIO
import NIOFoundationCompat
@_spi(CodableUtilities) import SQLKit

public struct MySQLDataEncoder: Sendable {
    let json: JSONEncoder

    public init(json: JSONEncoder = .init()) {
        self.json = json
    }
    
    public func encode(_ value: any Encodable) throws -> MySQLData {
        if let custom = value as? any MySQLDataConvertible {
            guard let data = custom.mysqlData else {
                throw EncodingError.invalidValue(value, .init(codingPath: [], debugDescription: "Couldn't get MySQL encoding from value '\(value)'"))
            }
            return data
        } else {
            do {
                let encoder = NestedSingleValueUnwrappingEncoder(dataEncoder: self)
                
                try value.encode(to: encoder)
                return encoder.value
            } catch is SQLCodingError {
                return MySQLData(
                    type: .string,
                    format: .text,
                    buffer: try self.json.encodeAsByteBuffer(value, allocator: .init()),
                    isUnsigned: true
                )
            }
        }
    }

    private final class NestedSingleValueUnwrappingEncoder: Encoder, SingleValueEncodingContainer {
        var userInfo: [CodingUserInfoKey: Any] { [:] }
        var codingPath: [any CodingKey] { [] }
        let dataEncoder: MySQLDataEncoder
        var value: MySQLData = .null
        
        init(dataEncoder: MySQLDataEncoder) {
            self.dataEncoder = dataEncoder
        }
        
        func container<K: CodingKey>(keyedBy: K.Type) -> KeyedEncodingContainer<K> {
            .invalid(at: self.codingPath)
        }
        
        func unkeyedContainer() -> any UnkeyedEncodingContainer {
            .invalid(at: self.codingPath)
        }
        
        func singleValueContainer() -> any SingleValueEncodingContainer {
            self
        }
        
        func encodeNil() throws {
            self.value = .null
        }
        
        func encode(_ value: Bool) throws {
            self.value = .init(bool: value)
        }
        
        func encode(_ value: String) throws {
            self.value = .init(string: value)
        }
        
        func encode(_ value: Float) throws {
            self.value = .init(float: value)
        }
        
        func encode(_ value: Double) throws {
            self.value = .init(double: value)
        }
        
        func encode(_ value: Int8) throws {
            self.value = .init(int: numericCast(value))
        }
        
        func encode(_ value: Int16) throws {
            self.value = .init(int: numericCast(value))
        }
        
        func encode(_ value: Int32) throws {
            self.value = .init(int: numericCast(value))
        }
        
        func encode(_ value: Int64) throws {
            self.value = .init(int: numericCast(value))
        }
        
        func encode(_ value: Int) throws {
            self.value = .init(int: value)
        }
        
        func encode(_ value: UInt8) throws {
            self.value = .init(int: numericCast(value))
        }
        
        func encode(_ value: UInt16) throws {
            self.value = .init(int: numericCast(value))
        }
        
        func encode(_ value: UInt32) throws {
            self.value = .init(int: numericCast(value))
        }
        
        func encode(_ value: UInt64) throws {
            self.value = .init(int: numericCast(value))
        }
        
        func encode(_ value: UInt) throws {
            self.value = .init(int: numericCast(value))
        }
        
        func encode(_ value: some Encodable) throws {
            self.value = try self.dataEncoder.encode(value)
        }
    }
}
