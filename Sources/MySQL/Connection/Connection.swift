import Bits
import Foundation
import Async
import TCP
import TLS
import Dispatch

/// Contains settings that MySQL uses to upgrade
public struct MySQLSSLConfig {
    var client: TLSSocket.Type
    var settings: TLSClientSettings
    
    public init(client: TLSSocket.Type, settings: TLSClientSettings) {
        self.client = client
        self.settings = settings
    }
}

/// A connectio to a MySQL database servers
public struct MySQLConnection {
    let stateMachine: MySQLStateMachine
    
    /// The inserted ID from the last successful query
    public var lastInsertID: UInt64? {
        return stateMachine.lastInsertID
    }
    
    /// Amount of affected rows in the last successful query
    public var affectedRows: UInt64? {
        return stateMachine.affectedRows
    }
    
    /// Creates a new connection
    ///
    /// Doesn't finish the handshake synchronously
    init(stateMachine: MySQLStateMachine) {
        self.stateMachine = stateMachine
    }
    
    /// Closes the connection
    public func close() {
        stateMachine.close()
    }
}

