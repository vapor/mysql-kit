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
    /// The state of the server's handshake
    var handshake: Handshake
    
    /// The incoming stream parser
    let parser: AnyOutputStream<Packet>
    
    let serializer: PushStream<Packet>
    
    let streamClose: () -> ()
    
    /// The inserted ID from the last successful query
    public var lastInsertID: UInt64?
    
    /// Amount of affected rows in the last successful query
    public var affectedRows: UInt64?
    
    /// Creates a new connection
    ///
    /// Doesn't finish the handshake synchronously
    init(
        handshake: Handshake,
        parser: AnyOutputStream<Packet>,
        serializer: PushStream<Packet>,
        close: @escaping () -> ()
    ) {
        self.streamClose = close
        self.handshake = handshake
        self.parser = parser
        self.serializer = serializer
    }

    deinit {
        self.close()
    }
    
    /// Closes the connection
    public func close() {
        // Write `close`
        serializer.next([
            0x01 // close identifier
        ])
        
        streamClose()
    }
}

