import NIOCore
import Logging
import MySQLNIO
import AsyncKit

/// A `ConnectionPoolSource` providing MySQL database connections for a given ``MySQLConfiguration``.
public struct MySQLConnectionSource: ConnectionPoolSource {
    /// A ``MySQLConfiguration`` used to create connections.
    public let configuration: MySQLConfiguration

    /// Create a ``MySQLConnectionSource``.
    ///
    /// - Parameter configuration: The configuration for new connections.
    public init(configuration: MySQLConfiguration) {
        self.configuration = configuration
    }

    // See `ConnectionPoolSource.makeConnection(logger:on:)`.
    public func makeConnection(logger: Logger, on eventLoop: any EventLoop) -> EventLoopFuture<MySQLConnection> {
        let address: SocketAddress
        
        do {
            address = try self.configuration.address()
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
        return MySQLConnection.connect(
            to: address,
            username: self.configuration.username,
            database: self.configuration.database ?? self.configuration.username,
            password: self.configuration.password,
            tlsConfiguration: self.configuration.tlsConfiguration,
            serverHostname: self.configuration._hostname,
            logger: logger,
            on: eventLoop
        )
    }
}

extension MySQLNIO.MySQLConnection: AsyncKit.ConnectionPoolItem {}  // Fully qualifying the type names implies @retroactive
