import Foundation
import MySQLNIO
import NIOFoundationCompat
@_spi(CodableUtilities) import SQLKit

/// Translates `Encodable` values into `MySQLData` values suitable for use with a `MySQLDatabase`.
///
/// Types which conform to `MySQLDataConvertible` are converted directly to `MySQLData`. Other types are
/// encoded as JSON and sent to the database as text.
public struct MySQLDataEncoder: Sendable {
    /// A wrapper to silence `Sendable` warnings for `JSONEncoder` when not on macOS.
    struct FakeSendable<T>: @unchecked Sendable { let value: T }
    
    /// The `JSONEncoder` used for encoding values that can't be directly converted.
    let json: FakeSendable<JSONEncoder>

    /// Initialize a ``MySQLDataEncoder`` with a JSON encoder.
    ///
    /// - Parameter json: A `JSONEncoder` to use for encoding types that can't be directly converted. Defaults
    ///   to an unconfigured encoder.
    public init(json: JSONEncoder = .init()) {
        self.json = .init(value: json)
    }
    
    /// Convert the given `Encodable` value to a `MySQLData` value, if possible.
    /// 
    /// - Parameter value: The value to convert.
    /// - Returns: A converted `MySQLData` value, if successful.
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
                guard let value = encoder.value else {
                    throw SQLCodingError.unsupportedOperation("missing value", codingPath: [])
                }
                return value
            } catch is SQLCodingError {
                return MySQLData(
                    type: .string,
                    format: .text,
                    buffer: try self.json.value.encodeAsByteBuffer(value, allocator: .init()),
                    isUnsigned: true
                )
            }
        }
    }

    /// A trivial encoder for unwrapping types which encode as trivial single-value containers. This allows for
    /// correct handling of types such as `Optional` when they do not conform to `MySQLDataCovnertible`.
    private final class NestedSingleValueUnwrappingEncoder: Encoder, SingleValueEncodingContainer {
        // See `Encoder.userInfo`.
        var userInfo: [CodingUserInfoKey: Any] { [:] }
        
        // See `Encoder.codingPath` and `SingleValueEncodingContainer.codingPath`.
        var codingPath: [any CodingKey] { [] }
        
        /// The parent ``MySQLDataEncoder``.
        let dataEncoder: MySQLDataEncoder
        
        /// Storage for the resulting converted value.
        var value: MySQLData? = nil
        
        /// Create a new encoder with a ``MySQLDataEncoder``.
        init(dataEncoder: MySQLDataEncoder) {
            self.dataEncoder = dataEncoder
        }
        
        // See `Encoder.container(keyedBy:)`.
        func container<K: CodingKey>(keyedBy: K.Type) -> KeyedEncodingContainer<K> {
            .invalid(at: self.codingPath)
        }
        
        // See `Encoder.unkeyedContainer`.
        func unkeyedContainer() -> any UnkeyedEncodingContainer {
            .invalid(at: self.codingPath)
        }
        
        // See `Encoder.singleValueContainer`.
        func singleValueContainer() -> any SingleValueEncodingContainer {
            self
        }
        
        // See `SingleValueEncodingContainer.encodeNil()`.
        func encodeNil() throws {
            self.value = .null
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: Bool) throws {
            self.value = .init(bool: value)
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: String) throws {
            self.value = .init(string: value)
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: Float) throws {
            self.value = .init(float: value)
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: Double) throws {
            self.value = .init(double: value)
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: Int8) throws {
            self.value = .init(int: numericCast(value))
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: Int16) throws {
            self.value = .init(int: numericCast(value))
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: Int32) throws {
            self.value = .init(int: numericCast(value))
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: Int64) throws {
            self.value = .init(int: numericCast(value))
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: Int) throws {
            self.value = .init(int: value)
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: UInt8) throws {
            self.value = .init(int: numericCast(value))
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: UInt16) throws {
            self.value = .init(int: numericCast(value))
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: UInt32) throws {
            self.value = .init(int: numericCast(value))
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: UInt64) throws {
            self.value = .init(int: numericCast(value))
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: UInt) throws {
            self.value = .init(int: numericCast(value))
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: some Encodable) throws {
            self.value = try self.dataEncoder.encode(value)
        }
    }
}

/// This conformance suppresses a slew of spurious warnings in some build environments.
extension MySQLNIO.MySQLProtocol.DataType: @unchecked Swift.Sendable {} // Fully qualifying the type names implies @retroactive
