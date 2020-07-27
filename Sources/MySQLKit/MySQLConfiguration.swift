@_exported import struct Foundation.URL
@_exported import struct Foundation.Data
@_exported import struct NIOSSL.TLSConfiguration

public struct MySQLConfiguration {
    public let address: () throws -> SocketAddress
    public let username: String
    public let password: String
    public let database: String?
    public let tlsConfiguration: TLSConfiguration?
    
    internal var _hostname: String?
    
    public init?(url: URL) {
        guard url.scheme?.hasPrefix("mysql") == true else {
            return nil
        }
        guard let username = url.user else {
            return nil
        }
        guard let password = url.password else {
            return nil
        }
        guard let hostname = url.host else {
            return nil
        }
        guard let port = url.port else {
            return nil
        }
        
        let tlsConfiguration: TLSConfiguration?
        if url.query == "ssl=false" {
            tlsConfiguration = nil
        } else {
            tlsConfiguration = .forClient()
        }
        
        self.init(
            hostname: hostname,
            port: port,
            username: username,
            password: password,
            database: url.path.split(separator: "/").last.flatMap(String.init),
            tlsConfiguration: tlsConfiguration
        )
    }

    public init(
        unixDomainSocketPath: String,
        username: String,
        password: String,
        database: String? = nil
    ) {
        self.address = {
            return try SocketAddress.init(unixDomainSocketPath: unixDomainSocketPath)
        }
        self.username = username
        self.password = password
        self.database = database
        self.tlsConfiguration = nil
        self._hostname = nil
    }
    
    public init(
        hostname: String,
        port: Int = 3306,
        username: String,
        password: String,
        database: String? = nil,
        tlsConfiguration: TLSConfiguration? = .forClient()
    ) {
        self.address = {
            return try SocketAddress.makeAddressResolvingHost(hostname, port: port)
        }
        self.username = username
        self.database = database
        self.password = password
        self.tlsConfiguration = tlsConfiguration
        self._hostname = hostname
    }
}
