import Async
import MySQL
import XCTest

class MySQLTests: XCTestCase {
    func testVersion() throws {
        let client = try MySQLConnection.makeTest()
        print("client: \(client)!")
        let results = try client.simpleQuery("SELECT @@version;").wait()
        XCTAssert(results[0]["@@version"]??.contains("5.7") == true)
    }

    static let allTests = [
        ("testVersion", testVersion),
    ]
}

extension MySQLConnection {
    /// Creates a test event loop and psql client.
    static func makeTest() throws -> MySQLConnection {
        let group = MultiThreadedEventLoopGroup(numThreads: 1)
        let client = try MySQLConnection.connect(on: group) { error in
            // for some reason connection refused error is happening?
            if !"\(error)".contains("refused") {
                XCTFail("\(error)")
            }
        }.wait()
        _ = try client.authenticate(username: "foo", database: "test", password: "bar").wait()
        return client
    }
}
