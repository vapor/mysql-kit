import Foundation
import NIOSSL
import NIOCore
import NIOPosix // for inet_pton()
import NIOConcurrencyHelpers

/// A set of parameters used to connect to a MySQL database.
public struct MySQLConfiguration: Sendable {
    /// Underlying storage for ``address``.
    private var _address: @Sendable () throws -> SocketAddress
    /// Underlying storage for ``username``.
    private var _username: String
    /// Underlying storage for ``password``.
    private var _password: String
    /// Underlying storage for ``database``.
    private var _database: String?
    /// Underlying storage for ``tlsConfiguration``.
    private var _tlsConfiguration: TLSConfiguration?
    /// Underlying storage for ``_hostname``.
    private var _internal_hostname: String?
    
    /// Lock for access to underlying storage.
    private let lock: NIOLock = .init()
    
    /// A closure which returns the NIO `SocketAddress` for a server.
    public var address: @Sendable () throws -> SocketAddress {
        get { self.lock.withLock { self._address } }
        set { self.lock.withLock { self._address = newValue } }
    }
    
    /// The username used to authenticate the connection.
    public var username: String {
        get { self.lock.withLock { self._username } }
        set { self.lock.withLock { self._username = newValue } }
    }
    
    /// The password used to authenticate the connection. May be an empty string.
    public var password: String {
        get { self.lock.withLock { self._password } }
        set { self.lock.withLock { self._password = newValue } }
    }
    
    /// An optional initial default database for the connection.
    public var database: String? {
        get { self.lock.withLock { self._database } }
        set { self.lock.withLock { self._database = newValue } }
    }
    
    /// Optional configuration for TLS-based connection encryption.
    public var tlsConfiguration: TLSConfiguration? {
        get { self.lock.withLock { self._tlsConfiguration } }
        set { self.lock.withLock { self._tlsConfiguration = newValue } }
    }

    /// The IANA-assigned port number for MySQL (3306).
    ///
    /// This is the default port used by MySQL servers. Equivalent to
    /// `UInt16(getservbyname("mysql", "tcp").pointee.s_port).byteSwapped`.
    public static var ianaPortNumber: Int { 3306 }

    var _hostname: String? {
        get { self.lock.withLock { self._internal_hostname } }
        set { self.lock.withLock { self._internal_hostname = newValue } }
    }

    /// Create a ``MySQLConfiguration`` from an appropriately-formatted URL string.
    /// 
    /// See ``MySQLConfiguration/init(url:)-4mmel`` for details of the accepted URL format.
    ///
    /// - Parameter url: A URL-formatted MySQL connection string. See ``init(url:)-4mmel`` for syntax details.
    /// - Returns: `nil` if `url` is not a valid RFC 3986 URI with an authority component (e.g. a URL).
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
        self._address = {
            try SocketAddress.init(unixDomainSocketPath: unixDomainSocketPath)
        }
        self._username = username
        self._password = password
        self._database = database
        self._tlsConfiguration = tlsConfiguration
        self._internal_hostname = nil
    }
    
    /// Create a ``MySQLConfiguration`` for connecting to a server with a hostname and optional port.
    ///
    /// - Parameters:
    ///   - hostname: The hostname to connect to.
    ///   - port: A TCP port number to connect on. Defaults to the IANA-assigned MySQL port number (3306).
    ///   - username: The username to use for the connection.
    ///   - password: The pasword (empty string for none) to use for the connection.
    ///   - database: The default database fr the connection, if any.
    ///   - tlsConfiguration: An optional `TLSConfiguration` specifying encryption for the connection.
    public init(
        hostname: String,
        port: Int = Self.ianaPortNumber,
        username: String,
        password: String,
        database: String? = nil,
        tlsConfiguration: TLSConfiguration? = .makeClientConfiguration()
    ) {
        self._address = {
            try SocketAddress.makeAddressResolvingHost(hostname, port: port)
        }
        self._username = username
        self._database = database
        self._password = password
        if let tlsConfiguration = tlsConfiguration {
            self._tlsConfiguration = tlsConfiguration

            // Temporary fix - this logic should be removed once MySQLNIO is updated
            var n4 = in_addr(), n6 = in6_addr()
            if inet_pton(AF_INET, hostname, &n4) != 1 && inet_pton(AF_INET6, hostname, &n6) != 1 {
                self._internal_hostname = hostname
            }
        }
    }
}
