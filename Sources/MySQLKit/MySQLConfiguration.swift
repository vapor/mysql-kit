import Foundation
import NIOSSL
import NIOCore
import NIOPosix // for inet_pton()

public struct MySQLConfiguration {
    public var address: () throws -> SocketAddress
    public var username: String
    public var password: String
    public var database: String?
    public var tlsConfiguration: TLSConfiguration?

    /// IANA-assigned port number for MySQL
    /// `UInt16(getservbyname("mysql", "tcp").pointee.s_port).byteSwapped`
    public static var ianaPortNumber: Int { 3306 }

    internal var _hostname: String?

    public init?(url: String) {
        guard let url = URL(string: url) else {
            return nil
        }
        self.init(url: url)
    }
    
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
        let port = url.port ?? Self.ianaPortNumber
        
        let tlsConfiguration: TLSConfiguration?
        if url.query == "ssl=false" {
            tlsConfiguration = nil
        } else {
            tlsConfiguration = .makeClientConfiguration()
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
        port: Int = Self.ianaPortNumber,
        username: String,
        password: String,
        database: String? = nil,
        tlsConfiguration: TLSConfiguration? = .makeClientConfiguration()
    ) {
        self.address = {
            return try SocketAddress.makeAddressResolvingHost(hostname, port: port)
        }
        self.username = username
        self.database = database
        self.password = password
        if let tlsConfiguration = tlsConfiguration {
            self.tlsConfiguration = tlsConfiguration

            // Temporary fix - this logic should be removed once MySQLNIO is updated
            var n4 = in_addr(), n6 = in6_addr()
            if inet_pton(AF_INET, hostname, &n4) != 1 && inet_pton(AF_INET6, hostname, &n6) != 1 {
                self._hostname = hostname
            }
        }
    }
}
