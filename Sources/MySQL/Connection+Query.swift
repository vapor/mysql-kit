import Foundation
import Core

extension Table {
    func query(_ sql: String, onConnection connection: Connection) throws -> Future<[Self]> {
        // Cannot send another SQL query before the other one is done
        _ = try connection.currentQueryFuture?.await()
        
        let resultBuilder = ResultsBuilder<Self>(connection: connection)
        
        let complete = connection.onPackets(resultBuilder.inputStream)
        let promise = Promise<[Self]>()
        
        resultBuilder.errorStream = { error in
            try! promise.complete(error)
            try! complete.complete(false)
        }
        
        resultBuilder.drain { results in
            try! promise.complete(results)
        }

        var buffer = Data()
        buffer.reserveCapacity(sql.utf8.count + 1)
        
        // SQL Query
        buffer.append(0x03)
        buffer.append(contentsOf: [UInt8](sql.utf8))
    
        do {
            try connection.write(packetFor: buffer)
        } catch {
            try promise.complete(error)
        }
        
        return promise.future
    }
}
