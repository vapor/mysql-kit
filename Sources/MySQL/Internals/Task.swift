import Async

protocol Task {
    func update(with packet: Packet) throws -> Bool
    func interrupted(by error: Error) throws
    
    var packets: [Packet] { get }
}

struct AnyTask {
    var task: Task
}

struct StartHandshake: Task {
    let context: MySQLStateMachine
    
    var packets: [Packet] { return [] }
    
    func update(with packet: Packet) throws -> Bool {
        // Incoming packet can be an error packet so fail fast
        // Do not silence the error!
        guard packet.payload.first != 0xff else {
            throw MySQLError(packet:packet)
        }
        
        let handshake = try context.doHandshake(from: packet)
        
        context.execute(SendHandshake(handshake: handshake, context: context))
        
        return true
    }
    
    func interrupted(by error: Error) {
        self.context.connected.fail(error)
    }
}

struct SendHandshake: Task {
    let handshake: Packet
    let context: MySQLStateMachine
    
    var packets: [Packet] { return [handshake] }
    
    func update(with packet: Packet) throws -> Bool {
        
        // Incoming packet can be an error packet so fail fast
        // Do not silence the error!
        guard packet.payload.first != 0xff else {
            throw MySQLError(packet:packet)
        }
        
        guard let packet = try context.finishAuthentication(for: packet) else {
            context.connected.complete()
            return true
        }
        
        context.execute(SendAuthentication(packet: packet, context: context))
        
        return true
    }
    
    func interrupted(by error: Error) {
        self.context.connected.fail(error)
    }
}

struct SendAuthentication: Task {
    let packet: Packet
    let context: MySQLStateMachine
    
    var packets: [Packet] { return [] }
    
    func update(with packet: Packet) throws -> Bool {
        // Incoming packet can be an error packet so fail fast
        // Do not silence the error!
        guard packet.payload.first != 0xff else {
            throw MySQLError(packet:packet)
        }
    
        _ = try packet.parseBinaryOK()
        
        return true
    }
    
    func interrupted(by error: Error) {
        self.context.connected.fail(error)
    }
}

final class ParseResults: Task {
    let stream: PushStream<Row>
    let context: MySQLStateMachine
    
    var columnCount: Int?
    var columns: [Field]
    var columnsCompleted = false
    
    var packets: [Packet] { return [] }
    
    init(stream: PushStream<Row>?, context: MySQLStateMachine) {
        self.stream = stream!
        self.context = context
        self.columns = []
    }
    
    func update(with packet: Packet) throws -> Bool {
        // Incoming packet can be an error packet so fail fast
        // Do not silence the error!
        guard packet.payload.first != 0xff else {
            throw MySQLError(packet:packet)
        }
        
        guard let columnCount = columnCount else {
            return try updateColumnCount(with: packet)
        }
        
        if columns.count == columnCount, columnsCompleted {
            return try parseRow(from: packet)
        } else {
            return try parseField(from: packet)
        }
    }
    
    private func parseField(from packet: Packet) throws -> Bool {
        if packet.payload.first == 0xfe {
            let eof = try EOF(packet: packet)
            
            if eof.flags & EOF.serverMoreResultsExists == 0 {
                self.columnsCompleted = true
                return false
            }
            
            return false
        }
        
        do {
            // Try to parse a column
            self.columns.append(try packet.parseFieldDefinition())
        } catch {
            // Failure might indicate no EOF is coming and a field is coming instead
            columnsCompleted = true
        }
        
        return false
    }
    
    private func parseRow(from packet: Packet) throws -> Bool {
        // End of Rows
        if packet.payload.first == 0xfe {
            if let (affectedRows, lastInsertID) = try packet.parseBinaryOK() {
                context.affectedRows = affectedRows
                context.lastInsertID = lastInsertID
                stream.close()
                return true
            }
            
            let eof = try EOF(packet: packet)
            
            if eof.flags & EOF.serverMoreResultsExists == 0 {
                stream.close()
                return true
            }
            
            return false
        }
        
        let row = try packet.parseRow(columns: columns)
        stream.push(row)
        
        return false
    }
    
    private func updateColumnCount(with packet: Packet) throws -> Bool {
        // Ignore EOF
        if packet.payload.first == 0xfe, packet.payload.count == 5 {
            return false
        }
        
        var parser = Parser(packet: packet)
        let length = try parser.parseLenEnc()
        
        guard length < Int.max else {
            throw MySQLError(.unexpectedResponse)
        }
        
        self.columnCount = numericCast(length)
        
        if length == 0 {
            if let (affectedRows, lastInsertID) = try packet.parseBinaryOK() {
                context.affectedRows = affectedRows
                context.lastInsertID = lastInsertID
            }
            
            return true
        }
        
        return false
    }
    
    func interrupted(by error: Error) {
        stream.error(error)
    }
    
    deinit {
        self.stream.close()
    }
}

/// COM_QUERY Command
/// https://mariadb.com/kb/en/library/com_query/
struct TextQuery: Task {
    let query: String
    let parse: ParseResults
    
    var packets: [Packet] {
        return [
            Packet(data: [0x03] + Array(query.utf8))
        ]
    }
    
    init(query: String, stream: PushStream<Row>, context: MySQLStateMachine) {
        self.query = query
        self.parse = ParseResults(stream: stream, context: context)
    }
    
    func update(with packet: Packet) throws -> Bool {
        // Incoming packet can be an error packet so fail fast
        // Do not silence the error!
        guard packet.payload.first != 0xff else {
            throw MySQLError(packet:packet)
        }
        
        return try parse.update(with: packet)
    }
    
    func interrupted(by error: Error) {
        parse.stream.error(error)
        parse.stream.close()
    }
}


/// COM_STMT_PREPARE command
/// https://mariadb.com/kb/en/library/com_stmt_prepare/
final class PrepareQuery: Task {
    typealias Callback = (PreparedStatement?, MySQLError?) -> ()
    
    let query: String
    let context: MySQLStateMachine
    let callback: Callback
    
    var parameters: [Field]
    var columns: [Field]
    
    var id: UInt32?
    var totalColumns: UInt16?
    var totalParameters: UInt16?
    
    var packets: [Packet] {
        return [
            Packet(data: [0x16] + Array(query.utf8))
        ]
    }
    
    init(query: String, context: MySQLStateMachine, callback: @escaping Callback) {
        self.query = query
        self.context = context
        self.callback = callback
        self.parameters = []
        self.columns = []
    }
    
    func update(with packet: Packet) throws -> Bool {
        // Incoming packet can be an error packet so fail fast
        // Do not silence the error!
        guard packet.payload.first != 0xff else {
            // We cannot just throw an MySQLError here, because the supplied closure must fail,
            // otherways we are endup with hanging Future.
            // So we are bubble up the error to the supplied closure and end the Task
            callback(nil, MySQLError(packet: packet))
            return true
        }
        
        if
            let id = id,
            let totalParameters = totalParameters,
            let totalColumns = totalColumns
        {
            if packet.payload.first == 0xfe, packet.payload.count == 5 {
                return false
            }
            
            if self.parameters.count < totalParameters {
                let field = try packet.parseFieldDefinition()
                parameters.append(field)
            } else if self.columns.count < totalColumns {
                let field = try packet.parseFieldDefinition()
                columns.append(field)
            }
            
            if self.parameters.count == totalParameters, self.columns.count == totalColumns {
                let statement = PreparedStatement(statementID: id, columns: self.columns, stateMachine: context, parameters: self.parameters)
                //call the callback with preparedStatement
                callback(statement, nil)
                
                return true
            }
            
            return false
        } else {
            var parser = Parser(packet: packet, position: 1)
            
            self.id = try parser.parseUInt32()
            self.totalColumns = try parser.parseUInt16()
            self.totalParameters = try parser.parseUInt16()
            
            return false
        }
    }
    
    func interrupted(by error: Error) {}
}
/// COM_QUIT Command
/// https://mariadb.com/kb/en/library/com_quit/
struct Close: Task {
    var packets: [Packet] {
        return [
            [0x01]
        ]
    }
    // No response from the server!
    func update(with packet: Packet) throws -> Bool {
        return true
    }
    
    func interrupted(by error: Error) { }
}


/// COM_STMT_CLOSE command
/// https://mariadb.com/kb/en/library/3-binary-protocol-prepared-statements-com_stmt_close/
struct ClosePreparation: Task {
    var id: UInt32
    
    var packets: [Packet] {
        var data = [UInt8](repeating: 0x19, count: 5)
        
        data.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 1) { pointer in
                pointer.pointee = id
            }
        }
        
        let packet = Packet(data: data)
        
        return [packet]
    }
    
    /// Response:
    /// No response from server.
    func update(with packet: Packet) throws -> Bool {
        return true
    }
    
    func interrupted(by error: Error) { }
}


/// COM_STMT_RESET Command
/// https://mariadb.com/kb/en/library/com_stmt_reset/
struct ResetPreparation: Task {
    var id: UInt32
    
    var packets: [Packet] {
        var data = [UInt8](repeating: 0x1a, count: 5)
        
        data.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 1) { pointer in
                pointer.pointee = id
            }
        }
        
        let packet = Packet(data: data)
        
        return [packet]
    }
    
    /// Response:
    /// ERR_Packet or OK_Packet
    
    func update(with packet: Packet) throws -> Bool {
        /// Incoming packet can be an error packet so fail fast
        /// incoming ERR packet means the prepared statement no longer valid.
        /// Do not silence the error!
        /// FIXME: invalidate statement id if error.
        guard packet.payload.first != 0xff else {
            throw MySQLError(packet:packet)
        }
        return true
    }
    
    func interrupted(by error: Error) { }
}

/// COM_STMT_FETCH Command
/// https://mariadb.com/kb/en/library/com_stmt_fetch/
struct GetMore: Task {
    var id: UInt32
    var amount: UInt32
    var output: AnyInputStream<Row>
    
    var packets: [Packet] {
        var data = [UInt8](repeating: 0x1c, count: 9)
        
        data.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 2) { pointer in
                pointer[0] = id
                pointer[1] = amount
            }
        }
        
        let packet = Packet(data: data)
        
        return [packet]
    }
    
    func update(with packet: Packet) throws -> Bool {
        // Incoming packet can be an error packet so fail fast
        // Do not silence the error!
        guard packet.payload.first != 0xff else {
            throw MySQLError(packet:packet)
        }
        // FIXME: Implement binary resultset row parsing and pass it up!
        // The protocol is good, only need to implement it properly
        // https://mariadb.com/kb/en/library/packet_bindata/
        return true
    }
    
    func interrupted(by error: Error) {
        output.error(error)
        output.close()
    }
}

/// COM_STMT_EXECUTE Command
/// https://mariadb.com/kb/en/library/com_stmt_execute/
struct ExecutePreparation: Task {
    func interrupted(by error: Error) {
        parse.stream.error(error)
        parse.stream.close()
    }
    
    let packet: Packet
    let parse: ParseResults
    
    var packets: [Packet] { return [packet] }
    
    // COM_STMT_EXECUTE response:
    // The server can answer with 3 different responses:
    // 0xff: ERR_Packet if any errors occur.
    // 0x00: OK_packet when query execution works without resultset.
    // Binary resultset
    func update(with packet: Packet) throws -> Bool {
        // Incoming packet can be an error packet so fail fast
        // Do not silence the error
        guard packet.payload.first != 0xff else {
            throw MySQLError(packet:packet)
        }
        return try parse.update(with: packet)
    }
}
