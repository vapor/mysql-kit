enum Response {
    struct State {
        let marker: UInt8
        let state: (UInt8, UInt8, UInt8, UInt8, UInt8)
    }
    
    case error(code: UInt16, state: State?, message: String)
    case ok(affectedRows: UInt64, lastInsertId: UInt64, status: UInt16?, warnings: UInt16?)
}

extension Packet {
    func parseResponse(mysql41: Bool) throws -> Response {
        guard self.payload.count > 1 else {
            throw MySQLError.invalidResponse
        }
        
        switch self.payload[0] {
        case 0xff:
            guard self.payload.count > 3 else {
                throw MySQLError.invalidResponse
            }
            
            let code = (UInt16(payload[1]) << 8) | UInt16(payload[2])
            
            if mysql41 {
                guard self.payload.count > 10 else {
                    throw MySQLError.invalidResponse
                }
                
                let state = Response.State(
                    marker: payload[3],
                    state: (payload[4], payload[5], payload[6], payload[7], payload[8])
                )
                
                let message = String(bytes: payload[9..<payload.endIndex], encoding: .utf8) ?? ""
                
                return .error(code: code, state: state, message: message)
            } else {
                let message = String(bytes: payload[3..<payload.endIndex], encoding: .utf8) ?? ""
                
                return .error(code: code, state: nil, message: message)
            }
        case 0x00:
            fallthrough
        case 0xfe:
            guard self.payload.count > 3 else {
                throw MySQLError.invalidResponse
            }
            
            var position = 1
            
            func parseUInt16() throws -> UInt16 {
                guard position &+ 2 < self.payload.count else {
                    throw MySQLError.invalidResponse
                }
                
                defer { position = position &+ 2 }
                
                let byte0 = UInt16(self.payload[position])
                let byte1 = UInt16(self.payload[position &+ 1]) << 8
                
                return byte0 | byte1
            }
            
            func parseUInt32() throws -> UInt32 {
                guard position &+ 2 < self.payload.count else {
                    throw MySQLError.invalidResponse
                }
                
                defer { position = position &+ 4 }
                
                let byte0 = UInt32(self.payload[position])
                let byte1 = UInt32(self.payload[position &+ 1]) << 8
                let byte2 = UInt32(self.payload[position &+ 2]) << 16
                let byte3 = UInt32(self.payload[position &+ 3]) << 24
                
                return byte0 | byte1 | byte2 | byte3
            }
            
            func parseUInt64() throws -> UInt64 {
                guard position &+ 2 < self.payload.count else {
                    throw MySQLError.invalidResponse
                }
                
                defer { position = position &+ 8 }
                
                let byte0 = UInt64(self.payload[position])
                let byte1 = UInt64(self.payload[position &+ 1]) << 8
                let byte2 = UInt64(self.payload[position &+ 2]) << 16
                let byte3 = UInt64(self.payload[position &+ 3]) << 24
                let byte4 = UInt64(self.payload[position &+ 4]) << 32
                let byte5 = UInt64(self.payload[position &+ 5]) << 40
                let byte6 = UInt64(self.payload[position &+ 6]) << 48
                let byte7 = UInt64(self.payload[position &+ 7]) << 56
                
                return byte0 | byte1 | byte2 | byte3 | byte4 | byte5 | byte6 | byte7
            }
            
            func parseLenEnc() throws -> UInt64 {
                guard position &+ 1 < self.payload.count else {
                    throw MySQLError.invalidResponse
                }
                
                switch self.payload[position] {
                case 0xfc:
                    position = position &+ 1
                    
                    return UInt64(try parseUInt16())
                case 0xfd:
                    position = position &+ 1
                    
                    return UInt64(try parseUInt32())
                case 0xfe:
                    position = position &+ 1
                    
                    return try parseUInt64()
                case 0xff:
                    throw MySQLError.invalidResponse
                default:
                    defer { position = position &+ 1 }
                    return UInt64(self.payload[position])
                }
            }
            
            let affectedRows = try parseLenEnc()
            let lastInsertedId = try parseLenEnc()
            let statusFlags: UInt16?
            let warnings: UInt16?
            
            if mysql41 {
                statusFlags = try parseUInt16()
                warnings = try parseUInt16()
                
                // TODO: CLIENT_SESSION_TRACK
                // TODO: SERVER_SESSION_STATE_CHANGED
            } else {
                statusFlags = nil
                warnings = nil
            }
            
            // TODO: Client transactions
            
            return .ok(affectedRows: affectedRows, lastInsertId: lastInsertedId, status: statusFlags, warnings: warnings)
        default:
            throw MySQLError.invalidResponse
        }
    }
}
