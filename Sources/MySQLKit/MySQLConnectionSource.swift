public struct MySQLConnectionSource: ConnectionPoolSource {
    public let configuration: MySQLConfiguration

    public init(configuration: MySQLConfiguration) {
        self.configuration = configuration
    }

    public func makeConnection(logger: Logger, on eventLoop: EventLoop) -> EventLoopFuture<MySQLConnection> {
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

extension MySQLConnection: ConnectionPoolItem { }
