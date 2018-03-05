import Async
import MySQL
import XCTest

class MySQLTests: XCTestCase {
    func testVersion() throws {
//        let client = try MySQLConnection.makeTest()
//        let results = try client.simpleQuery("SELECT @@version as version;").wait()
//        try XCTAssert(results[0]["version"]?.decode(String.self).contains("10.") == true)
    }

    static let allTests = [
        ("testVersion", testVersion),
    ]
}

//extension MySQLConnection {
//    /// Creates a test event loop and psql client.
//    static func makeTest() throws -> MySQLConnection {
//        let group = MultiThreadedEventLoopGroup(numThreads: 1)
//        let client = try MySQLConnection.connect(on: group) { error in
//            XCTFail("\(error)")
//        }.wait()
//        _ = try client.authenticate(username: "root", database: "vapor_test").wait()
//        return client
//    }
//}

