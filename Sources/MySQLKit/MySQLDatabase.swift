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
        guard url.scheme == "mysql" else {
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
        if url.query == "ssl=true" {
            tlsConfiguration = TLSConfiguration.forClient(certificateVerification: .none)
        } else {
            tlsConfiguration = nil
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
        hostname: String,
        port: Int = 3306,
        username: String,
        password: String,
        database: String? = nil,
        tlsConfiguration: TLSConfiguration? = nil
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
    public var eventLoop: EventLoop
    public let configuration: MySQLConfiguration
    
    public init(configuration: MySQLConfiguration, on eventLoop: EventLoop) {
        self.configuration = configuration
        self.eventLoop = eventLoop
    }
    
    public func makeConnection() -> EventLoopFuture<MySQLConnection> {
        let address: SocketAddress
        do {
            address = try self.configuration.address()
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
        return MySQLConnection.connect(
            to: address,
            username: self.configuration.username,
            database: self.configuration.database ?? self.configuration.username,
            password: self.configuration.password,
            tlsConfiguration: self.configuration.tlsConfiguration,
            on: self.eventLoop
        )
    }
}

extension MySQLConnection: ConnectionPoolItem { }

extension MySQLRow: SQLRow {
    public func decode<D>(column: String, as type: D.Type) throws -> D where D : Decodable {
        guard let data = self.column(column) else {
            fatalError()
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

struct MySQLDialect: SQLDialect {
    private var bindOffset: Int
    
    init() {
        self.bindOffset = 0
    }
    
    var identifierQuote: SQLExpression {
        return SQLRaw("`")
    }
    
    var literalStringQuote: SQLExpression {
        return SQLRaw("'")
    }
    
    mutating func nextBindPlaceholder() -> SQLExpression {
        return SQLRaw("?")
    }
    
    func literalBoolean(_ value: Bool) -> SQLExpression {
        switch value {
        case false:
            return SQLRaw("0")
        case true:
            return SQLRaw("1")
        }
    }
    
    var autoIncrementClause: SQLExpression {
        return SQLRaw("AUTO_INCREMENT")
    }
}

extension MySQLConnection: SQLDatabase { }

extension MySQLDatabase where Self: SQLDatabase {
    public func sqlQuery(_ query: SQLExpression, _ onRow: @escaping (SQLRow) throws -> ()) -> EventLoopFuture<Void> {
        var serializer = SQLSerializer(dialect: MySQLDialect())
        query.serialize(to: &serializer)
        return self.query(serializer.sql, serializer.binds.map { encodable in
            return try! MySQLDataEncoder().encode(encodable)
        }, onRow: { row in
            try! onRow(row)
        }, onMetadata: { metadata in
            print(metadata)
        })
    }
}

#warning("TODO: move to SQLKit?")
extension ConnectionPool: SQLDatabase where Source.Connection: SQLDatabase {
    public func sqlQuery(_ query: SQLExpression, _ onRow: @escaping (SQLRow) throws -> ()) -> EventLoopFuture<Void> {
        return self.withConnection { $0.sqlQuery(query, onRow) }
    }
}


#warning("TODO: move to NIOPostgres?")
//extension ConnectionPool: PostgresDatabase where Source.Connection: PostgresDatabase {
//    public var eventLoop: EventLoop {
//        return self.source.eventLoop
//    }
//    
//    public func send(_ request: PostgresRequestHandler) -> EventLoopFuture<Void> {
//        return self.withConnection { $0.send(request) }
//    }
//}

#warning("TODO: move to SQLKit?")

