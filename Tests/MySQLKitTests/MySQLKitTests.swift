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
        // try benchmark.run()
    }
}

extension MySQLConnection {
    static func test(on eventLoop: EventLoop) -> EventLoopFuture<MySQLConnection> {
        do {
            let address: SocketAddress
            // socket:
            // try .init(unixDomainSocketPath: "/tmp/mysqld.sock")
            #if os(Linux)
            address = try .makeAddressResolvingHost("mysql", port: 3306)
            #else
            address = try .init(ipAddress: "127.0.0.1", port: 3306)
            #endif
            let tlsConfig: TLSConfiguration?
            #if TEST_TLS
            tlsConfig = .forClient(certificateVerification: .none)
            #else
            tlsConfig = nil
            #endif
            return self.connect(
                to: address,
                username: "vapor_username",
                database: "vapor_database",
                password: "vapor_password",
                tlsConfig: tlsConfig,
                on: eventLoop
            )
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
}
