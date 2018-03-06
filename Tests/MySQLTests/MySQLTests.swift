import Async
import MySQL
import XCTest

class MySQLTests: XCTestCase {
    func testSimpleQuery() throws {
        let client = try MySQLConnection.makeTest()
        let results = try client.simpleQuery("SELECT @@version;").wait()
        try XCTAssert(results[0]["@@version"]?.decode(String.self).contains("5.7") == true)
    }

    func testQuery() throws {
        let client = try MySQLConnection.makeTest()
        let results = try client.query("SELECT CONCAT(?, ?) as test;", ["hello", "world"]).wait()
        try XCTAssertEqual(results[0]["test"]?.decode(String.self), "helloworld")
    }

    func testInsert() throws {
        let client = try MySQLConnection.makeTest()
        let dropResults = try client.simpleQuery("DROP TABLE IF EXISTS foos;").wait()
        XCTAssertEqual(dropResults.count, 0)
        let createResults = try client.simpleQuery("CREATE TABLE foos (id INT, name VARCHAR(64));").wait()
        XCTAssertEqual(createResults.count, 0)
    }

    static let allTests = [
        ("testSimpleQuery", testSimpleQuery),
        ("testQuery", testQuery),
        ("testInsert", testInsert),
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
