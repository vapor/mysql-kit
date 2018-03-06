extension MySQLConnection {
    /// Connects to a MySQL server using TCP.
    public static func connect(
        hostname: String = "localhost",
        port: Int = 3306,
        on worker: Worker,
        onError: @escaping (Error) -> ()
    ) throws -> Future<MySQLConnection> {
        let handler = QueueHandler<MySQLPacket, MySQLPacket>(on: worker, onError: onError)
        let bootstrap = ClientBootstrap(group: worker.eventLoop)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return channel.pipeline.addMySQLClientHandlers().then {
                    channel.pipeline.add(handler: handler)
                }
        }

        return bootstrap.connect(host: hostname, port: port).map(to: MySQLConnection.self) { channel in
            return .init(queue: handler, channel: channel)
        }
    }
}

extension ChannelPipeline {
    /// Adds MySQL packet encoder and decoder to the channel pipeline.
    func addMySQLClientHandlers(first: Bool = false) -> EventLoopFuture<Void> {
        let session = MySQLConnectionSession()
        return addHandlers(MySQLPacketEncoder(session: session), MySQLPacketDecoder(session: session), first: first)
    }

    /// Adds the provided channel handlers to the pipeline in the order given, taking account
    /// of the behaviour of `ChannelHandler.add(first:)`.
    private func addHandlers(_ handlers: ChannelHandler..., first: Bool) -> EventLoopFuture<Void> {
        var handlers = handlers
        if first {
            handlers = handlers.reversed()
        }

        return EventLoopFuture<Void>.andAll(handlers.map { add(handler: $0) }, eventLoop: eventLoop)
    }
}
