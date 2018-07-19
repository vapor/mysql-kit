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
        let ready = worker.eventLoop.newPromise(Void.self)
        let handler = MySQLConnectionHandler(config: config, ready: ready)
        let bootstrap = ClientBootstrap(group: worker.eventLoop)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return channel.pipeline.addMySQLClientHandlers().then {
                    return channel.pipeline.add(handler: handler)
                }
            }
        let channel = bootstrap.connect(host: config.hostname, port: config.port)
        channel.catch { ready.fail(error: $0) }
        return channel.flatMap { channel in
            let conn = MySQLConnection(handler: handler, channel: channel)
            return ready.futureResult.transform(to: conn)
        }
    }
}

extension ChannelPipeline {
    /// Adds MySQL packet encoder and decoder to the channel pipeline.
    public func addMySQLClientHandlers(first: Bool = false) -> Future<Void> {
        let session = MySQLPacketState()
        return addHandlers(MySQLPacketEncoder(session: session), MySQLPacketDecoder(session: session), first: first)
    }
}
