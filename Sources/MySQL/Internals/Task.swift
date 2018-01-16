import Async

enum Task {
    case close
    case textQuery(String, AnyInputStream<Row>)
    case prepare(String, (PreparedStatement) -> ())
    case closePreparation(UInt32)
    case resetPreparation(UInt32)
    case executePreparation([UInt8], StreamState.QueryContext) // raw packet
    case getMore(UInt32, StreamState.QueryContext)
    case none
    
    var packet: Packet? {
        switch self {
        case .close:
            return [0x01]
        case .textQuery(let query, _):
            return Packet(data: [0x03] + Array(query.utf8))
        case .prepare(let query, _):
            return Packet(data: [0x16] + Array(query.utf8))
        case .closePreparation(let id):
            var data = [UInt8](repeating: 0x19, count: 5)
            
            data.withUnsafeMutableBufferPointer { buffer in
                buffer.baseAddress!.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 1) { pointer in
                    pointer.pointee = id
                }
            }
            
            return Packet(data: data)
        case .resetPreparation(let id):
            var data = [UInt8](repeating: 0x1a, count: 5)
            
            data.withUnsafeMutableBufferPointer { buffer in
                buffer.baseAddress!.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 1) { pointer in
                    pointer.pointee = id
                }
            }
            
            return Packet(data: data)
        case .getMore(let amount, let context):
            guard let id = context.binary else {
                return nil
            }
            
            var data = [UInt8](repeating: 0x1c, count: 9)
            
            data.withUnsafeMutableBufferPointer { buffer in
                buffer.baseAddress!.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 2) { pointer in
                    pointer[0] = id
                    pointer[1] = amount
                }
            }
            
            return Packet(data: data)
        case .executePreparation(let data, _):
            return Packet(data: data)
        case .none:
            return nil
        }
    }
}
