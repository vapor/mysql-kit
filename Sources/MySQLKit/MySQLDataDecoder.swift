//import Foundation
//
//#warning("TODO: move to codable kit")
//struct DecoderUnwrapper: Decodable {
//    let decoder: Decoder
//    init(from decoder: Decoder) {
//        self.decoder = decoder
//    }
//}
//
//public struct PostgresDataDecoder {
//    public init() {}
//    
//    public func decode<T>(_ type: T.Type, from data: PostgresData) throws -> T
//        where T: Decodable
//    {
//        return try T.init(from: _Decoder(data: data))
//    }
//    
//    #warning("TODO: finish implementing")
//    
//    private final class _Decoder: Decoder {
//        var codingPath: [CodingKey] {
//            return []
//        }
//        
//        var userInfo: [CodingUserInfoKey : Any] {
//            return [:]
//        }
//        
//        let data: PostgresData
//        init(data: PostgresData) {
//            self.data = data
//        }
//        
//        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
//            fatalError()
//        }
//        
//        func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
//            #warning("TODO: use NIOFoundationCompat")
//            var buffer = self.data.value!
//            let data = buffer.readBytes(length: buffer.readableBytes)!
//            let unwrapper = try JSONDecoder().decode(DecoderUnwrapper.self, from: Data(data))
//            return try unwrapper.decoder.container(keyedBy: Key.self)
//        }
//        
//        func singleValueContainer() throws -> SingleValueDecodingContainer {
//            return _SingleValueDecoder(self)
//        }
//    }
//    
//    private struct _SingleValueDecoder: SingleValueDecodingContainer {
//        var codingPath: [CodingKey] {
//            return self.decoder.codingPath
//        }
//        let decoder: _Decoder
//        init(_ decoder: _Decoder) {
//            self.decoder = decoder
//        }
//        
//        func decodeNil() -> Bool {
//            return self.decoder.data.value == nil
//        }
//        
//        func decode(_ type: Bool.Type) throws -> Bool {
//            fatalError()
//        }
//        
//        func decode(_ type: String.Type) throws -> String {
//            return self.decoder.data.string!
//        }
//        
//        func decode(_ type: Double.Type) throws -> Double {
//            return self.decoder.data.double!
//        }
//        
//        func decode(_ type: Float.Type) throws -> Float {
//            return self.decoder.data.float!
//        }
//        
//        func decode(_ type: Int.Type) throws -> Int {
//            return self.decoder.data.int!
//        }
//        
//        func decode(_ type: Int8.Type) throws -> Int8 {
//            fatalError()
//        }
//        
//        func decode(_ type: Int16.Type) throws -> Int16 {
//            fatalError()
//        }
//        
//        func decode(_ type: Int32.Type) throws -> Int32 {
//            fatalError()
//        }
//        
//        func decode(_ type: Int64.Type) throws -> Int64 {
//            return self.decoder.data.int64!
//        }
//        
//        func decode(_ type: UInt.Type) throws -> UInt {
//            fatalError()
//        }
//        
//        func decode(_ type: UInt8.Type) throws -> UInt8 {
//            fatalError()
//        }
//        
//        func decode(_ type: UInt16.Type) throws -> UInt16 {
//            fatalError()
//        }
//        
//        func decode(_ type: UInt32.Type) throws -> UInt32 {
//            fatalError()
//        }
//        
//        func decode(_ type: UInt64.Type) throws -> UInt64 {
//            fatalError()
//        }
//        
//        func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
//            return try T.init(from: self.decoder)
//        }
//        
//    }
//}
