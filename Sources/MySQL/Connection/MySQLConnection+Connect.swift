import Crypto

extension MySQLConnection {    
    /// Connects to a MySQL server using TCP.
    public static func connect(
        config: MySQLDatabaseConfig,
        on worker: Worker,
        onError: @escaping (Error) -> ()
    ) -> Future<MySQLConnection> {
        let handler = MySQLConnectionHandler(config: config)
        let bootstrap = ClientBootstrap(group: worker.eventLoop)
        .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        .channelInitializer { channel in
            return channel.pipeline.addMySQLClientHandlers().then {
                channel.pipeline.add(handler: handler)
            }
        }
        return bootstrap.connect(host: config.hostname, port: config.port).map { channel -> MySQLConnection in
            return .init(handler: handler, channel: channel)
        }.flatMap { conn in
            let rfq = worker.eventLoop.newPromise(Void.self)
            handler.readyForQuery = rfq
            return rfq.futureResult.map { conn }
        }
    }
}

extension ChannelPipeline {
    /// Adds MySQL packet encoder and decoder to the channel pipeline.
    func addMySQLClientHandlers(first: Bool = false) -> Future<Void> {
        let session = MySQLPacketState()
        return addHandlers(MySQLPacketEncoder(session: session), MySQLPacketDecoder(session: session), first: first)
    }
}
