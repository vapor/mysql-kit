import MySQLKit
import SQLKitBenchmark
import XCTest

class MySQLKitTests: XCTestCase {
    private var group: EventLoopGroup!
    private var eventLoop: EventLoop {
        return self.group.next()
    }
    
    override func setUp() {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    override func tearDown() {
        XCTAssertNoThrow(try self.group.syncShutdownGracefully())
        self.group = nil
    }
    
    
    func testSQLKitBenchmark() throws {
        let conn = try MySQLConnection.test(on: self.eventLoop).wait()
        defer { try! conn.close().wait() }
        let benchmark = SQLBenchmarker(on: conn)
        print(benchmark)
        // try benchmark.run()
    }
}

extension MySQLConnection {
    static func test(on eventLoop: EventLoop) -> EventLoopFuture<MySQLConnection> {
        do {
            let hostname = ProcessInfo.processInfo.environment["MYSQL_HOSTNAME"] ?? "localhost"
            let port = ProcessInfo.processInfo.environment["MYSQL_PORT"].flatMap(Int.init) ?? 3306
            let tls: TLSConfiguration? = ProcessInfo.processInfo.environment["MYSQL_TLS"] != nil
                ? .forClient(certificateVerification: .none)
                : nil
            return try self.connect(
                to: .makeAddressResolvingHost(hostname, port: port),
                username: "vapor_username",
                database: "vapor_database",
                password: "vapor_password",
                tlsConfiguration: tls,
                on: eventLoop
            )
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
}
