@_exported import struct Foundation.URL
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

public struct MySQLConnectionSource: ConnectionPoolSource {
    public let configuration: MySQLConfiguration
    
    public init(configuration: MySQLConfiguration) {
        self.configuration = configuration
    }
    
    public func makeConnection(logger: Logger, on eventLoop: EventLoop) -> EventLoopFuture<MySQLConnection> {
        let address: SocketAddress
        do {
            address = try self.configuration.address()
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
        return MySQLConnection.connect(
            to: address,
            username: self.configuration.username,
            database: self.configuration.database ?? self.configuration.username,
            password: self.configuration.password,
            tlsConfiguration: self.configuration.tlsConfiguration,
            logger: logger,
            on: eventLoop
        )
    }
}

extension MySQLConnection: ConnectionPoolItem { }

struct MissingColumn: Error {
    let column: String
}

extension MySQLRow: SQLRow {
    public var allColumns: [String] {
        self.columnDefinitions.map { $0.name }
    }

    public func contains(column: String) -> Bool {
        self.columnDefinitions.contains { $0.name == column }
    }

    public func decodeNil(column: String) throws -> Bool {
        guard let data = self.column(column) else {
            return true
        }
        return data.buffer == nil
    }

    public func decode<D>(column: String, as type: D.Type) throws -> D where D : Decodable {
        guard let data = self.column(column) else {
            throw MissingColumn(column: column)
        }
        return try MySQLDataDecoder().decode(D.self, from: data)
    }
}

public struct SQLRaw: SQLExpression {
    public var string: String
    public init(_ string: String) {
        self.string = string
    }
    
    public func serialize(to serializer: inout SQLSerializer) {
        serializer.write(self.string)
    }
}

public struct MySQLDialect: SQLDialect {
    public init() {}
    
    public var name: String {
        "mysql"
    }
    
    public var identifierQuote: SQLExpression {
        return SQLRaw("`")
    }
    
    public var literalStringQuote: SQLExpression {
        return SQLRaw("'")
    }
    
    public func bindPlaceholder(at position: Int) -> SQLExpression {
        return SQLRaw("?")
    }

    public func literalBoolean(_ value: Bool) -> SQLExpression {
        switch value {
        case false:
            return SQLRaw("0")
        case true:
            return SQLRaw("1")
        }
    }
    
    public var autoIncrementClause: SQLExpression {
        return SQLRaw("AUTO_INCREMENT")
    }

    public var supportsAutoIncrement: Bool {
        true
    }

    public var enumSyntax: SQLEnumSyntax {
        .inline
    }

    public func customDataType(for dataType: SQLDataType) -> SQLExpression? {
        switch dataType {
        case .text:
            return SQLRaw("VARCHAR(255)")
        default:
            return nil
        }
    }

    public var alterTableSyntax: SQLAlterTableSyntax {
        .init(
            alterColumnDefinitionClause: SQLRaw("MODIFY COLUMN"),
            alterColumnDefinitionTypeKeyword: nil
        )
    }
    
    public func normalizeSQLConstraint(identifier: SQLExpression) -> SQLExpression {
        return SQLHashedExpression(identifier)
    }
}
