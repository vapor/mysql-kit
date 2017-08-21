import Foundation
import Core

extension Connection {
    func query(_ sql: String) throws -> Future<Results> {
        // Cannot send another SQL query before the other one is done
        _ = try self.onResults?.future.await()
        
        let promise = Promise<Results>()

        var buffer = Data()
        
        // SQL Query
        buffer.append(0x03)
        buffer.append(contentsOf: [UInt8](sql.utf8))
    
        try self.write(packetFor: buffer)
        
        self.onResults = promise
        
        promise.future.then { _ in
            self.onResults = nil
        }
        
        return promise.future
    }
}
