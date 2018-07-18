import NIOOpenSSL

/// Supported options for MySQL connection TLS.
public struct MySQLTransportConfig {
    /// Does not attempt to enable TLS (this is the default).
    public static var cleartext: MySQLTransportConfig {
        return .init(method: .cleartext)
    }
    
    /// Enables TLS requiring a minimum version of TLS v1.1 on the server, but disables certificate verification.
    public static var unverifiedTLS: MySQLTransportConfig {
        return .init(method: .tls(.forClient(certificateVerification: .none)))
    }
    
    /// Enables TLS requiring a minimum version of TLS v1.1 on the server.
    public static var standardTLS: MySQLTransportConfig {
        return .init(method: .tls(.forClient()))
    }
    
    /// Enables TLS requiring a minimum version of TLS v1.2 on the server.
    public static var modernTLS: MySQLTransportConfig {
        return .init(method: .tls(.forClient(minimumTLSVersion: .tlsv12)))
    }
    
    /// Enables TLS requiring a minimum version of TLS v1.3 on the server.
    /// TLS v1.3 specification is still a draft and unlikely to be supported by most servers.
    /// See https://tools.ietf.org/html/draft-ietf-tls-tls13-28 for more info.
    public static var edgeTLS: MySQLTransportConfig {
        return .init(method: .tls(.forClient(minimumTLSVersion: .tlsv13)))
    }
    
    /// Enables TLS using the given `TLSConfiguration`.
    /// - parameter tlsConfiguration: See `TLSConfiguration` for more info.
    public static func customTLS(_ tlsConfiguration: TLSConfiguration)-> MySQLTransportConfig {
        return .init(method: .tls(tlsConfiguration))
    }
    
    /// Returns `true` if this configuration uses TLS.
    public var isTLS: Bool {
        switch storage {
        case .cleartext: return false
        case .tls: return true
        }
    }
    
    /// Internal storage type.
    internal enum Storage {
        case cleartext
        case tls(TLSConfiguration)
    }
    
    /// Internal storage.
    internal let storage: Storage
    
    /// Internal init.
    internal init(method: Storage) {
        self.storage = method
    }
}
