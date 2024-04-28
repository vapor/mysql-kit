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
    
    /// Create a ``MySQLConfiguration`` from an appropriately-formatted `URL`.
    ///
    /// The supported URL formats are:
    ///
    ///     mysql://username:password@hostname:port/database?ssl-mode=mode
    ///     mysql+tcp://username:password@hostname:port/database?ssl-mode=mode
    ///     mysql+uds://username:password@localhost/path?ssl-mode=mode#database
    ///
    /// The `mysql+tcp` scheme requests a connection over TCP. The `mysql` scheme is an alias
    /// for `mysql+tcp`. Only the `hostname` and `username` components are required.
    ///
    /// The ` mysql+uds` scheme requests a connection via a UNIX domain socket. The `username` and
    /// `path` components are required. The authority must always be empty or `localhost`, and may not
    /// specify a port.
    ///
    /// The allowed `mode` values for `ssl-mode` are:
    ///
    /// Value|Behavior
    /// -|-
    /// `DISABLED`|Don't use TLS, even if the server supports it.
    /// `PREFERRED`|Use TLS if possible.
    /// `REQUIRED`|Enforce TLS support, including CA and hostname verification.
    ///
    /// `ssl-mode` values are case-insensitive. `VERIFY_CA` and `VERIFY_IDENTITY` are accepted as aliases
    /// of `REQUIRED`. `tls-mode`, `tls`, and `ssl` are recognized aliases of `ssl-mode`.
    ///
    /// If no `ssl-mode` is specified, the default mode is `REQUIRED` for TCP connections, or `DISABLED`
    /// for UDS connections. If more than one mode is specified, the last one wins. Whenever a TLS
    /// connection is made, full certificate verification (both chain of trust and hostname match)
    /// is always enforced, regardless of the mode used.
    ///
    /// > Warning: At this time of this writing, `PREFERRED` is the same as `REQUIRED`, due to
    /// > limitations of the underlying implementation. A future version will remove this restriction.
    ///
    /// > Note: It is possible to emulate `libmysqlclient`'s definitions for `REQUIRED` (TLS enforced, but
    /// > without certificate verification) and `VERIFY_CA` (TLS enforced with no hostname verification) by
    /// > manually specifying the TLS configuration instead of using a URL.  It is _strongly_ recommended for
    /// > both security and privacy reasons to always leave full certificate verification enabled whenever
    /// > possible. See NIOSSL's [`TLSConfiguration`](tlsconfig) for additional information and recommendations.
    ///
    /// [tlsconfig]:
    /// https://swiftpackageindex.com/apple/swift-nio-ssl/main/documentation/niossl/tlsconfiguration
    ///
    /// - Parameter url: A `URL` containing MySQL connection parameters.
    /// - Returns: `nil` if `url` is missing required information or has an invalid scheme.
    public init?(url: URL) {
        guard let comp = URLComponents(url: url, resolvingAgainstBaseURL: true), let username = comp.user else {
            return nil
        }
        
        func decideTLSConfig(from queryItems: [URLQueryItem], defaultMode: String) -> TLSConfiguration?? {
            switch queryItems.last(where: { ["ssl-mode", "tls-mode", "tls", "ssl"].contains($0.name.lowercased()) })?.value ?? defaultMode {
            case "REQUIRED", "VERIFY_CA", "VERIFY_IDENTITY", "PREFERRED": return .some(.some(.makeClientConfiguration()))
            case "DISABLED": return .some(.none)
            default: return .none
            }
        }
        
        switch comp.scheme {
        case "mysql", "mysql+tcp":
            guard let hostname = comp.host, !hostname.isEmpty else {
                return nil
            }
            guard case .some(let tlsConfig) = decideTLSConfig(from: comp.queryItems ?? [], defaultMode: "REQUIRED") else {
                return nil
            }
            self.init(
                hostname: hostname, port: comp.port ?? Self.ianaPortNumber,
                username: username, password: comp.password ?? "",
                database: url.lastPathComponent.isEmpty ? nil : url.lastPathComponent, tlsConfiguration: tlsConfig
            )
        case "mysql+uds":
            guard (comp.host?.isEmpty ?? true || comp.host == "localhost"), comp.port == nil, !comp.path.isEmpty, comp.path != "/" else {
                return nil
            }
            guard case .some(let tlsConfig) = decideTLSConfig(from: comp.queryItems ?? [], defaultMode: "DISABLED") else {
                return nil
            }
            self.init(
                unixDomainSocketPath: comp.path,
                username: username, password: comp.password ?? "",
                database: comp.fragment, tlsConfiguration: tlsConfig
            )
        default:
            return nil
        }
    }
    
    /// Create a ``MySQLConfiguration`` for connecting to a server through a UNIX domain socket.
    /// 
    /// - Parameters:
    ///   - unixDomainSocketPath: The path to the UNIX domain socket to connect through.
    ///   - username: The username to use for the connection.
    ///   - password: The password (empty string for none) to use for the connection.
    ///   - database: The default database for the connection, if any.
    public init(
        unixDomainSocketPath: String,
        username: String,
        password: String,
        database: String? = nil
    ) {
        self.init(
            unixDomainSocketPath: unixDomainSocketPath,
            username: username,
            password: password,
            database: database,
            tlsConfiguration: nil
        )
    }
    
    /// Create a ``MySQLConfiguration`` for connecting to a server through a UNIX domain socket.
    /// 
    /// - Parameters:
    ///   - unixDomainSocketPath: The path to the UNIX domain socket to connect through.
    ///   - username: The username to use for the connection.
    ///   - password: The password (empty string for none) to use for the connection.
    ///   - database: The default database for the connection, if any.
    ///   - tlsConfiguration: An optional `TLSConfiguration` specifying encryption for the connection.
    public init(
        unixDomainSocketPath: String,
        username: String,
        password: String,
        database: String? = nil,
        tlsConfiguration: TLSConfiguration?
    ) {
        self.address = {
            return try SocketAddress.init(unixDomainSocketPath: unixDomainSocketPath)
        }
        self.username = username
        self.password = password
        self.database = database
        self.tlsConfiguration = tlsConfiguration
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
