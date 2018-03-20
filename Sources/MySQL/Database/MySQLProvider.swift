import Service

/// Provides base `MySQL` services such as database and connection.
public final class MySQLProvider: Provider {
    /// See `Provider.repositoryName`
    public static let repositoryName = "mysql"

    /// Creates a new `MySQLProvider`.
    public init() {}

    /// See `Provider.register`
    public func register(_ services: inout Services) throws {
        try services.register(DatabaseKitProvider())
        services.register(MySQLDatabaseConfig.self)
        services.register(MySQLDatabase.self)
        var databases = DatabaseConfig()
        databases.add(database: MySQLDatabase.self, as: .mysql)
        services.register(databases)
    }

    /// See `Provider.boot`
    public func didBoot(_ worker: Container) throws -> Future<Void> {
        return .done(on: worker)
    }
}

/// MARK: Services

extension MySQLDatabaseConfig: ServiceType {
    /// See `ServiceType.makeService(for:)`
    public static func makeService(for worker: Container) throws -> MySQLDatabaseConfig {
        return .root(database: "vapor")
    }
}
extension MySQLDatabase: ServiceType {
    /// See `ServiceType.makeService(for:)`
    public static func makeService(for worker: Container) throws -> MySQLDatabase {
        return try .init(config: worker.make())
    }
}

