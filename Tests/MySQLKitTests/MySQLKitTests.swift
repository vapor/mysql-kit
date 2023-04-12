import Logging
import MySQLKit
import SQLKitBenchmark
import XCTest
import NIOSSL
import AsyncKit
import SQLKit
import MySQLNIO

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

    /// Tests dealing with encoding of values whose `encode(to:)` implementation calls one of the `superEncoder()`
    /// methods (most notably the implementation of `Codable` for Fluent's `Fields`, which we can't directly test
    /// at this layer).
    func testValuesThatUseSuperEncoder() throws {
        struct UnusualType: Codable {
            var prop1: String, prop2: [Bool], prop3: [[Bool]]
            
            // This is intentionally contrived - Fluent's implementation does Codable this roundabout way as a
            // workaround for the interaction of property wrappers with optional properties; it serves no purpose
            // here other than to demonstrate that the encoder supports it.
            private enum CodingKeys: String, CodingKey { case prop1, prop2, prop3 }
            init(prop1: String, prop2: [Bool], prop3: [[Bool]]) { (self.prop1, self.prop2, self.prop3) = (prop1, prop2, prop3) }
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.prop1 = try .init(from: container.superDecoder(forKey: .prop1))
                var acontainer = try container.nestedUnkeyedContainer(forKey: .prop2), ongoing: [Bool] = []
                while !acontainer.isAtEnd { ongoing.append(try Bool.init(from: acontainer.superDecoder())) }
                self.prop2 = ongoing
                var bcontainer = try container.nestedUnkeyedContainer(forKey: .prop3), bongoing: [[Bool]] = []
                while !bcontainer.isAtEnd {
                    var ccontainer = try bcontainer.nestedUnkeyedContainer(), congoing: [Bool] = []
                    while !ccontainer.isAtEnd { congoing.append(try Bool.init(from: ccontainer.superDecoder())) }
                    bongoing.append(congoing)
                }
                self.prop3 = bongoing
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try self.prop1.encode(to: container.superEncoder(forKey: .prop1))
                var acontainer = container.nestedUnkeyedContainer(forKey: .prop2)
                for val in self.prop2 { try val.encode(to: acontainer.superEncoder()) }
                var bcontainer = container.nestedUnkeyedContainer(forKey: .prop3)
                for arr in self.prop3 {
                    var ccontainer = bcontainer.nestedUnkeyedContainer()
                    for val in arr { try val.encode(to: ccontainer.superEncoder()) }
                }
            }
        }
        
        let instance = UnusualType(prop1: "hello", prop2: [true, false, false, true], prop3: [[true, true], [false], [true], []])
        let encoded1 = try MySQLDataEncoder().encode(instance)
        let encoded2 = try MySQLDataEncoder().encode([instance, instance])
        
        XCTAssertEqual(encoded1.type, .string)
        XCTAssertEqual(encoded2.type, .string)
        
        let decoded1 = try MySQLDataDecoder().decode(UnusualType.self, from: encoded1)
        let decoded2 = try MySQLDataDecoder().decode([UnusualType].self, from: encoded2)
        
        XCTAssertEqual(decoded1.prop3, instance.prop3)
        XCTAssertEqual(decoded2.count, 2)
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
            username: env("MYSQL_USERNAME") ?? "test_username",
            password: env("MYSQL_PASSWORD") ?? "test_password",
            database: env("MYSQL_DATABASE") ?? "test_database",
            tlsConfiguration: tls
        )
        self.pools = .init(
            source: .init(configuration: configuration),
            maxConnectionsPerEventLoop: 2,
            requestTimeout: .seconds(30),
            logger: .init(label: "codes.vapor.mysql"),
            on: self.eventLoopGroup
        )
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
