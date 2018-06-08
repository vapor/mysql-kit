extension MySQLConnection {
    /// Connects to a MySQL server using TCP.
    @available(*, deprecated, message: "Authentication is now done during connect. Use `connect(config:)` instead.")
    public static func connect(
        hostname: String = "localhost",
        port: Int = 3306,
        on worker: Worker,
        onError: @escaping (Error) -> ()
    ) throws -> Future<MySQLConnection> {
        return try connect(config: .init(hostname: hostname, port: port), on: worker, onError: onError)
    }
}
