import Crypto

extension MySQLConnection {    
    /// Connects to a MySQL server using TCP.
    ///
    ///     MySQLConnection.connect(config: .root(database: "vapor"), on: ...)
    ///
    /// - parameters:
    ///     - config: Connection configuration options.
    ///     - worker: Event loop to run the connection on.
    public static func connect(config: MySQLDatabaseConfig, on worker: Worker) -> Future<MySQLConnection> {
        let helper = MySQLBootstrapHelper(config: config, on: worker)
        let bootstrap = ClientBootstrap(group: worker.eventLoop)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { helper.channelInitializer($0) }
        return bootstrap.connect(host: config.hostname, port: config.port)
            .flatMap { helper.connect($0) }
    }
}

extension ChannelPipeline {
    /// Adds MySQL packet encoder and decoder to the channel pipeline.
    public func addMySQLClientHandlers(first: Bool = false) -> Future<Void> {
        let session = MySQLPacketState()
        return addHandlers(MySQLPacketEncoder(session: session), MySQLPacketDecoder(session: session), first: first)
    }
}

/// Helps configure a NIO bootstrap for connecting to MySQL.
///
///     let helper = MySQLBootstrapHelper(config: config, on: worker)
///     let bootstrap = ClientBootstrap(group: worker.eventLoop)
///         .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
///         .channelInitializer { helper.channelInitializer($0) }
///     let connection = bootstrap.connect(host: config.hostname, port: config.port)
///         .flatMap { helper.connect($0) }
///     print(connection) // Future<MySQLConnection>
///
public final class MySQLBootstrapHelper {
    let handler: MySQLConnectionHandler
    let ready: Future<Void>
   
    /// Creates a new `MySQLBootstrapHelper`.
    public init(config: MySQLDatabaseConfig, on worker: Worker) {
        let ready = worker.eventLoop.newPromise(Void.self)
        self.ready = ready.futureResult
        handler = MySQLConnectionHandler(config: config, ready: ready)
    }
    
    /// Initializes a NIO `Channel`. Call this method in a bootstrap's
    /// `channelInitializer` callback.
    public func channelInitializer(_ channel: Channel) -> Future<Void> {
        return channel.pipeline.addMySQLClientHandlers().then {
            return channel.pipeline.add(handler: self.handler)
        }
    }
    
    /// Creates a `MySQLConnection` from a NIO `Channel`. Use this method
    /// to convert a bootstrap's connected `Channel` to a `MySQLConnection`.
    public func connect(_ channel: Channel) -> Future<MySQLConnection> {
        let conn = MySQLConnection(handler: handler, channel: channel)
        return ready.transform(to: conn)
    }
}
