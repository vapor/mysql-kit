import Foundation

class RowDecoder : DecoderHelper {
    func integers(for value: Column) throws -> Integers? {
        switch value {
        case .uint64(let num): return .uint64(num)
        case .int64(let num): return .int64(num)
        case .uint32(let num): return .uint32(num)
        case .int32(let num): return .int32(num)
        case .uint16(let num): return .uint16(num)
        case .int16(let num): return .int16(num)
        case .uint8(let num): return .uint8(num)
        case .int8(let num): return .int8(num)
        case .double(let num): return .double(num)
        case .float(let num): return .float(num)
        default: return nil
        }
    }
    
    var either: Either<Column, Row, NSNull>
    
    var lossyIntegers: Bool
    
    var lossyStrings: Bool
    
    init(row: Row, lossyIntegers: Bool, lossyStrings: Bool) {
        self.either = .keyed(row)
        self.lossyIntegers = lossyIntegers
        self.lossyStrings = lossyStrings
    }
    
    init(from: RowDecoder) {
        self.either = from.either
        self.lossyIntegers = from.lossyIntegers
        self.lossyStrings = from.lossyStrings
    }
    
    func decode(_ wrapped: Column) throws -> String {
        guard case .varString(let data) = wrapped, let string = String(bytes: data, encoding: .utf8) else {
            throw DecodingError.incorrectValue
        }
        
        return string
    }
    
    typealias Value = Column
    typealias Keyed = Row
    typealias Unkeyed = NSNull
    
    public var codingPath: [CodingKey] = []
    
    public var userInfo: [CodingUserInfoKey : Any] = [:]
    
    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        throw DecodingError.unimplemented
    }
    
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.unimplemented
    }
    
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return ColumnContainer(decoder: self)
    }
}

struct ColumnContainer : SingleValueDecodingContainerHelper {
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let decoder = RowDecoder(from: self.decoder)
        
        return try T(from: decoder)
    }
    
    func decode(_ type: String.Type) throws -> String {
        let value = try decoder.either.getValue()
        
        if case .varString(let data) = value {
            guard let string = String(bytes: data, encoding: .utf8) else {
                throw DecodingError.incorrectValue
            }
            
            return string
        } else {
            throw DecodingError.incorrectValue
        }
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        let value = try decoder.either.getValue()
        
        if case .int8(let num) = value {
            return num == 1
        } else if case .uint8(let num) = value {
            return num == 1
        } else {
            throw DecodingError.incorrectValue
        }
    }
    
    var codingPath: [CodingKey]
    
    func decodeNil() -> Bool {
        guard let value = try? decoder.either.getValue() else {
            return true
        }
        
        if case .null = value {
            return true
        }
        
        return false
    }
    
    let decoder: RowDecoder
    
    init(decoder: RowDecoder) {
        self.decoder = decoder
        self.codingPath = decoder.codingPath
    }
}
