import Logging
import MySQLKit
import SQLKitBenchmark
import XCTest

final class MySQLKitTests: XCTestCase {
    func testSQLBenchmark() async throws {
        try await SQLBenchmarker(on: self.sql).runAllTests()
    }

    func testNullDecode() throws {
        struct Person: Codable {
            let id: Int
            let name: String?
        }

        let rows = try self.sql.raw("SELECT 1 as `id`, null as `name`")
            .all(decoding: Person.self)
            .wait()
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

        try db.drop(table: "foo").ifExists().run().wait()
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
            private enum CodingKeys: String, CodingKey {
                case prop1, prop2, prop3
            }
            
            init(prop1: String, prop2: [Bool], prop3: [[Bool]]) {
                (self.prop1, self.prop2, self.prop3) = (prop1, prop2, prop3)
            }
            
            init(from decoder: any Decoder) throws {
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

            func encode(to encoder: any Encoder) throws {
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
    
    func testMySQLURLFormats() {
        let config1 = MySQLConfiguration(url: "mysql+tcp://test_username:test_password@test_hostname:9999/test_database?ssl-mode=DISABLED")
        XCTAssertNotNil(config1)
        XCTAssertEqual(config1?.database, "test_database")
        XCTAssertEqual(config1?.password, "test_password")
        XCTAssertEqual(config1?.username, "test_username")
        XCTAssertNil(config1?.tlsConfiguration)

        let config2 = MySQLConfiguration(url: "mysql+tcp://test_username@test_hostname")
        XCTAssertNotNil(config2)
        XCTAssertNil(config2?.database)
        XCTAssertEqual(config2?.password, "")
        XCTAssertEqual(config2?.username, "test_username")
        XCTAssertNotNil(config2?.tlsConfiguration)

        let config3 = MySQLConfiguration(url: "mysql+uds://test_username:test_password@localhost/tmp/mysql.sock?ssl-mode=REQUIRED#test_database")
        XCTAssertNotNil(config3)
        XCTAssertEqual(config3?.database, "test_database")
        XCTAssertEqual(config3?.password, "test_password")
        XCTAssertEqual(config3?.username, "test_username")
        XCTAssertNotNil(config3?.tlsConfiguration)

        let config4 = MySQLConfiguration(url: "mysql+uds://test_username@/tmp/mysql.sock")
        XCTAssertNotNil(config4)
        XCTAssertNil(config4?.database)
        XCTAssertEqual(config4?.password, "")
        XCTAssertEqual(config4?.username, "test_username")
        XCTAssertNil(config4?.tlsConfiguration)
        
        for modestr in ["ssl-mode=DISABLED", "tls-mode=VERIFY_IDENTITY&ssl-mode=DISABLED"] {
            let config = MySQLConfiguration(url: "mysql://u@h?\(modestr)")
            XCTAssertNotNil(config)
            XCTAssertNil(config?.tlsConfiguration)
            XCTAssertNil(config?.tlsConfiguration)
        }

        for modestr in [
            "ssl-mode=PREFERRED", "ssl-mode=REQUIRED", "ssl-mode=VERIFY_CA",
            "ssl-mode=VERIFY_IDENTITY", "tls-mode=VERIFY_IDENTITY", "ssl=VERIFY_IDENTITY",
            "tls-mode=PREFERRED&ssl-mode=VERIFY_IDENTITY"
        ] {
            let config = MySQLConfiguration(url: "mysql://u@h?\(modestr)")
            XCTAssertNotNil(config, modestr)
            XCTAssertNotNil(config?.tlsConfiguration, modestr)
        }
        
        XCTAssertNotNil(MySQLConfiguration(url: "mysql://test_username@test_hostname"))
        XCTAssertNotNil(MySQLConfiguration(url: "mysql+tcp://test_username@test_hostname"))
        XCTAssertNotNil(MySQLConfiguration(url: "mysql+uds://test_username@/tmp/mysql.sock"))
        
        XCTAssertNil(MySQLConfiguration(url: "mysql+tcp://test_username:test_password@/test_database"), "should fail when hostname missing")
        XCTAssertNil(MySQLConfiguration(url: "mysql+tcp://test_hostname"), "should fail when username missing")
        XCTAssertNil(MySQLConfiguration(url: "mysql+tcp://test_username@test_hostname?ssl-mode=absurd"), "should fail when TLS mode invalid")
        XCTAssertNil(MySQLConfiguration(url: "mysql+uds://localhost/tmp/mysql.sock?ssl-mode=REQUIRED"), "should fail when username missing")
        XCTAssertNil(MySQLConfiguration(url: "mysql+uds:///tmp/mysql.sock"), "should fail when authority missing")
        XCTAssertNil(MySQLConfiguration(url: "mysql+uds://test_username@localhost/"), "should fail when path missing")
        XCTAssertNil(MySQLConfiguration(url: "mysql+uds://test_username@remotehost/tmp"), "should fail when authority not localhost or empty")
        XCTAssertNil(MySQLConfiguration(url: "mysql+uds://test_username@localhost/tmp?ssl-mode=absurd"), "should fail when TLS mode invalid")
        XCTAssertNil(MySQLConfiguration(url: "postgres://test_username@remotehost/tmp"), "should fail when scheme is not mysql")

        XCTAssertNil(MySQLConfiguration(url: "$$$://postgres"), "should fail when invalid URL")
    }

    var sql: any SQLDatabase {
        self.mysql.sql()
    }

    var mysql: any MySQLDatabase {
        self.pools.database(logger: .init(label: "codes.vapor.mysql"))
    }

    var eventLoopGroup: any EventLoopGroup = MultiThreadedEventLoopGroup.singleton
    var pools: EventLoopGroupConnectionPool<MySQLConnectionSource>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        XCTAssertTrue(isLoggingConfigured)

        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateVerification = .none

        let configuration = MySQLConfiguration(
            hostname: env("MYSQL_HOSTNAME") ?? "localhost",
            port: env("MYSQL_PORT").flatMap(Int.init) ?? MySQLConfiguration.ianaPortNumber,
            username: env("MYSQL_USERNAME") ?? "test_username",
            password: env("MYSQL_PASSWORD") ?? "test_password",
            database: env("MYSQL_DATABASE") ?? "test_database",
            tlsConfiguration: tls
        )
        self.pools = .init(
            source: .init(configuration: configuration),
            maxConnectionsPerEventLoop: System.coreCount,
            requestTimeout: .seconds(30),
            logger: .init(label: "codes.vapor.mysql"),
            on: self.eventLoopGroup
        )
    }

    override func tearDownWithError() throws {
        try self.pools.syncShutdownGracefully()
        self.pools = nil
        
        try super.tearDownWithError()
    }
}

func env(_ name: String) -> String? {
    getenv(name).flatMap { String(cString: $0) }
}

let isLoggingConfigured: Bool = {
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardOutput(label: label)
        handler.logLevel = env("LOG_LEVEL").flatMap { .init(rawValue: $0) } ?? .debug
        return handler
    }
    return true
}()
