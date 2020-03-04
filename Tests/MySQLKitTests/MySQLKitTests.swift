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

        let rows = try self.db.raw("SELECT 1 as `id`, null as `name`")
            .all(decoding: Person.self).wait()
        XCTAssertEqual(rows[0].id, 1)
        XCTAssertEqual(rows[0].name, nil)
    }

    var db: SQLDatabase {
        self.connection.sql()
    }
    var benchmark: SQLBenchmarker {
        .init(on: self.db)
    }

    var eventLoopGroup: EventLoopGroup!
    var connection: MySQLConnection!

    override func setUp() {
        XCTAssertTrue(isLoggingConfigured)
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        self.connection = try! MySQLConnection.test(
            on: self.eventLoopGroup.next()
        ).wait()
        _ = try! self.connection.simpleQuery("DROP DATABASE vapor_database").wait()
        _ = try! self.connection.simpleQuery("CREATE DATABASE vapor_database").wait()
        _ = try! self.connection.simpleQuery("USE vapor_database").wait()
    }

    override func tearDown() {
        try! self.connection.close().wait()
        self.connection = nil
        try! self.eventLoopGroup.syncShutdownGracefully()
        self.eventLoopGroup = nil
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
        handler.logLevel = .debug
        return handler
    }
    return true
}()
