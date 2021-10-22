import Logging
import MySQLKit
import SQLKitBenchmark
import XCTest
import NIOSSL
import AsyncKit

class MySQLKitTests: XCTestCase {
    func testSQLBenchmark() throws {
        try SQLBenchmarker(on: self.sql).run()
    }

    func testNullDecode() throws {
        struct Person: Codable {
            let id: Int
            let name: String?
        }

        let rows = try self.sql.raw("SELECT 1 as `id`, null as `name`")
            .all(decoding: Person.self).wait()
        XCTAssertEqual(rows[0].id, 1)
        XCTAssertEqual(rows[0].name, nil)
    }

    func testCustomJSONCoder() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let db = self.mysql.sql(encoder: .init(json: encoder), decoder: .init(json: decoder))

        struct Foo: Codable, Equatable {
            var bar: Bar
        }
        struct Bar: Codable, Equatable {
            var baz: Date
        }

        try db.create(table: "foo")
            .column("bar", type: .custom(SQLRaw("JSON")))
            .run().wait()
        defer { try! db.drop(table: "foo").ifExists().run().wait() }

        let foo = Foo(bar: .init(baz: .init(timeIntervalSince1970: 1337)))
        try db.insert(into: "foo").model(foo).run().wait()

        let rows = try db.select().columns("*").from("foo").all(decoding: Foo.self).wait()
        XCTAssertEqual(rows, [foo])
    }

    var sql: SQLDatabase {
        self.mysql.sql()
    }

    var mysql: MySQLDatabase {
        self.pools.database(logger: .init(label: "codes.vapor.mysql"))
    }

    var eventLoopGroup: EventLoopGroup!
    var pools: EventLoopGroupConnectionPool<MySQLConnectionSource>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        XCTAssertTrue(isLoggingConfigured)
        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateVerification = .none
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        let configuration = MySQLConfiguration(
            hostname: env("MYSQL_HOSTNAME") ?? "localhost",
            port: env("MYSQL_PORT").flatMap(Int.init) ?? 3306,
            username: env("MYSQL_USERNAME") ?? "vapor_username",
            password: env("MYSQL_PASSWORD") ?? "vapor_password",
            database: env("MYSQL_DATABASE") ?? "vapor_database",
            tlsConfiguration: tls
        )
        self.pools = .init(
            source: .init(configuration: configuration),
            maxConnectionsPerEventLoop: 2,
            requestTimeout: .seconds(30),
            logger: .init(label: "codes.vapor.mysql"),
            on: self.eventLoopGroup
        )

        // Reset database.
        _ = try self.mysql.withConnection { conn in
            return conn.simpleQuery("DROP DATABASE vapor_database").flatMap { _ in
                conn.simpleQuery("CREATE DATABASE vapor_database")
            }.flatMap { _ in
                conn.simpleQuery("USE vapor_database")
            }
        }.wait()
    }

    override func tearDownWithError() throws {
        try self.pools.syncShutdownGracefully()
        self.pools = nil
        try self.eventLoopGroup.syncShutdownGracefully()
        self.eventLoopGroup = nil
        try super.tearDownWithError()
    }
}

func env(_ name: String) -> String? {
    getenv(name).flatMap { String(cString: $0) }
}

let isLoggingConfigured: Bool = {
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardOutput(label: label)
        handler.logLevel = env("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) } ?? .debug
        return handler
    }
    return true
}()
