import Logging
import MySQLKit
import SQLKitBenchmark
import XCTest

class MySQLKitTests: XCTestCase {
    func testSQLKitBenchmark() throws {
        try self.benchmark.run()
    }
    
    func testEnum() throws {
        try self.benchmark.testEnum()
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
        self.pool.pool(for: self.eventLoopGroup.next())
            .database(logger: .init(label: "codes.vapor.mysql"))
    }

    var benchmark: SQLBenchmarker {
        .init(on: self.sql)
    }

    var eventLoopGroup: EventLoopGroup!
    var pool: EventLoopGroupConnectionPool<MySQLConnectionSource>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        XCTAssertTrue(isLoggingConfigured)
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        self.pool = .init(
            source: .init(configuration: .init(
                hostname: env("MYSQL_HOSTNAME") ?? "localhost",
                port: 3306,
                username: "vapor_username",
                password: "vapor_password",
                database: "vapor_database",
                tlsConfiguration: .forClient(certificateVerification: .none)
            )),
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
        try self.pool.syncShutdownGracefully()
        self.pool = nil
        try self.eventLoopGroup.syncShutdownGracefully()
        self.eventLoopGroup = nil
        try super.tearDownWithError()
    }
}

extension MySQLConnection {
    static func test(on eventLoop: EventLoop) -> EventLoopFuture<MySQLConnection> {
        do {
            return try self.connect(
                to: .makeAddressResolvingHost(env("MYSQL_HOSTNAME") ?? "localhost", port: 3306),
                username: "vapor_username",
                database: "vapor_database",
                password: "vapor_password",
                tlsConfiguration: .forClient(certificateVerification: .none),
                on: eventLoop
            )
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
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
