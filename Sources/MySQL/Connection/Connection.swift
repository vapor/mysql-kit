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
public final class MySQLConnection {
    var stateMachine: MySQLStateMachine
    
    /// The inserted ID from the last successful query
    public var lastInsertID: UInt64?
    
    /// Amount of affected rows in the last successful query
    public var affectedRows: UInt64?
    
    /// Creates a new connection
    ///
    /// Doesn't finish the handshake synchronously
    init(
        handshake: Handshake,
        parser: ConnectingStream<Packet>,
        serializer: PushStream<Packet>
    ) {
        self.stateMachine = MySQLStateMachine(
            handshake: handshake,
            parser: parser,
            serializer: serializer
        )
    }
    
    /// Closes the connection
    public func close() {
        stateMachine.close()
    }
}

