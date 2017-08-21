import XCTest
@testable import MySQL
//import JSON
import Core

class MySQLTests: XCTestCase {
    static let allTests = [
        ("testExample", testExample)
//        ("testSelectVersion", testSelectVersion),
//        ("testTables", testTables),
//        ("testParameterization", testParameterization),
//        ("testDates", testDates),
//        ("testTimestamps", testTimestamps),
//        ("testSpam", testSpam),
//        ("testError", testError),
//        ("testTransaction", testTransaction),
//        ("testTransactionFailed", testTransactionFailed),
//        ("testBlob", testBlob),
//        ("testLongtext", testLongtext),
    ]

    override func setUp() {
        
    }
    
    func testExample() throws {
        let connection = try Connection(hostname: "localhost", user: "root", password: nil, database: nil, queue: .global())
        sleep(5000)
    }

//    func testSelectVersion() throws {
//        let results = try mysql
//            .makeConnection()
//            .execute("SELECT @@version, @@version, 1337, 3.14, 'what up', NULL")
//
//        guard let version = results[0, "@@version"]?.string else {
//            XCTFail("Version not in results")
//            return
//        }
//
//        XCTAssert(version.characters.first == "5")
//    }
//
//    func testTables() throws {
//        let conn = try mysql.makeConnection()
//
//        // insert data
//        try conn.execute("DROP TABLE IF EXISTS foo")
//        try conn.execute("CREATE TABLE foo (bar INT(4), baz VARCHAR(16))")
//        try conn.execute("INSERT INTO foo VALUES (42, 'Life')")
//        try conn.execute("INSERT INTO foo VALUES (1337, 'Elite')")
//        try conn.execute("INSERT INTO foo VALUES (9, NULL)")
//
//        // verify data
//        if let result = try conn.execute("SELECT * FROM foo WHERE bar = 42")[0]?.object {
//            XCTAssertEqual(result["bar"]?.int, 42)
//            XCTAssertEqual(result["baz"]?.string, "Life")
//        } else {
//            XCTFail("Could not get bar result")
//        }
//        if let result = try conn.execute("SELECT * FROM foo where baz = 'elite'")[0]?.object {
//            XCTAssertEqual(result["bar"]?.int, 1337)
//            XCTAssertEqual(result["baz"]?.string, "Elite")
//        } else {
//            XCTFail("Could not get baz result")
//        }
//        if let result = try conn.execute("SELECT * FROM foo where bar = 9")[0]?.object {
//            XCTAssertEqual(result["bar"]?.int, 9)
//            XCTAssertEqual(result["baz"]?.string, nil)
//        } else {
//            XCTFail("Could not get null result")
//        }
//    }
//
//    func testParameterization() throws {
//        let conn = try mysql.makeConnection()
//
//        try conn.execute("DROP TABLE IF EXISTS parameterization")
//        try conn.execute("CREATE TABLE parameterization (d DOUBLE, i INT, s VARCHAR(16), u INT UNSIGNED)")
//
//        try conn.execute("INSERT INTO parameterization VALUES (3.14, NULL, 'pi', NULL)")
//        try conn.execute("INSERT INTO parameterization VALUES (NULL, NULL, 'life', 42)")
//        try conn.execute("INSERT INTO parameterization VALUES (NULL, -1, 'test', NULL)")
//        try conn.execute("INSERT INTO parameterization VALUES (NULL, -1, 'test', NULL)")
//
//        if let result = try conn.execute("SELECT * FROM parameterization WHERE d = ?", ["3.14"])[0]?.object {
//            XCTAssertEqual(result["d"]?.double, 3.14)
//            XCTAssertEqual(result["i"]?.int, nil)
//            XCTAssertEqual(result["s"]?.string, "pi")
//            XCTAssertEqual(result["u"]?.int, nil)
//        } else {
//            XCTFail("Could not get pi result")
//        }
//
//        if let result = try conn.execute("SELECT * FROM parameterization WHERE u = ?", [42])[0]?.object {
//            XCTAssertEqual(result["d"]?.double, nil)
//            XCTAssertEqual(result["i"]?.int, nil)
//            XCTAssertEqual(result["s"]?.string, "life")
//            XCTAssertEqual(result["u"]?.int, 42)
//        } else {
//            XCTFail("Could not get life result")
//        }
//
//        if let result = try conn.execute("SELECT * FROM parameterization WHERE i = ?", [-1])[0]?.object {
//            XCTAssertEqual(result["d"]?.double, nil)
//            XCTAssertEqual(result["i"]?.int, -1)
//            XCTAssertEqual(result["s"]?.string, "test")
//            XCTAssertEqual(result["u"]?.int, nil)
//        } else {
//            XCTFail("Could not get test by int result")
//        }
//
//        if let result = try conn.execute("SELECT * FROM parameterization WHERE s = ?", ["test"])[0]?.object {
//            XCTAssertEqual(result["d"]?.double, nil)
//            XCTAssertEqual(result["i"]?.int, -1)
//            XCTAssertEqual(result["s"]?.string, "test")
//            XCTAssertEqual(result["u"]?.int, nil)
//        } else {
//            XCTFail("Could not get test by string result")
//        }
//    }
//
//    func testDates() throws {
//        let conn = try mysql.makeConnection()
//        let inputDate = Date()
//
//        try conn.execute("DROP TABLE IF EXISTS times")
//        try conn.execute("CREATE TABLE times (date DATETIME)")
//        try conn.execute("INSERT INTO times VALUES (?)", [Node.date(inputDate)])
//        let results = try conn.execute("SELECT * from times")
//
//        if let node = results[0, "date"], case let .date(retrievedDate) = node.wrapped {
//            // make ints to more accurately compare
//            let r = Int(retrievedDate.timeIntervalSince1970)
//            let i = Int(inputDate.timeIntervalSince1970)
//            XCTAssertEqual(r, i, "Mismatched dates. Found: \(retrievedDate) Expected: \(inputDate)")
//        } else {
//            XCTFail("Unable to retrieve date")
//        }
//    }
//
//    func testTimestamps() throws {
//        let conn = try mysql.makeConnection()
//
//        try conn.execute("DROP TABLE IF EXISTS times")
//        try conn.execute("CREATE TABLE times (i INT, d DATE, t TIME, ts TIMESTAMP)")
//
//
//        try conn.execute("INSERT INTO times VALUES (?, ?, ?, ?)", [
//            1.0,
//            "2050-05-12",
//            "13:42",
//            "2005-05-05 05:05:05"
//        ])
//
//
//        if let result = try conn.execute("SELECT i, ts FROM times")[0]?.object {
//            // 113142373505 = Thu, 05 May 2005 05:05:05 GMT
//            XCTAssertEqual(result["ts"]?.double, 1115269505)
//        } else {
//            XCTFail("No results")
//        }
//    }
//
//    func testSpam() throws {
//        let conn = try mysql.makeConnection()
//
//        try conn.execute("DROP TABLE IF EXISTS spam")
//        try conn.execute("CREATE TABLE spam (s VARCHAR(64), time TIME)")
//
//        for _ in 0..<10_000 {
//            try conn.execute("INSERT INTO spam VALUES (?, ?)", ["hello", "13:42"])
//        }
//
//        let conn2 = try mysql.makeConnection()
//        try conn2.execute("SELECT * FROM spam")
//    }
//
//    func testError() throws {
//        let conn = try mysql.makeConnection()
//
//        do {
//            try conn.execute("error")
//            XCTFail("Should have errored.")
//        } catch let error as MySQLError where error.code == .parseError {
//            // good
//            print(error.fullIdentifier)
//        } catch {
//            XCTFail("Wrong error: \(error)")
//        }
//    }
//
//    func testTransaction() throws {
//        let conn = try mysql.makeConnection()
//
//        try conn.execute("DROP TABLE IF EXISTS transaction")
//        try conn.execute("CREATE TABLE transaction (name VARCHAR(64))")
//        try conn.execute("INSERT INTO transaction VALUES (?)", [
//            "james"
//        ])
//
//        try conn.transaction {
//            _ = try conn.execute("UPDATE transaction SET name = 'James' where name = 'james'")
//        }
//
//        if let name = try conn.execute("SELECT * FROM transaction")["0", "name"]?.string {
//            XCTAssertEqual(name, "James")
//        } else {
//            XCTFail("There should be one entry.")
//        }
//    }
//
//    func testTransactionFailed() throws {
//        let c = try mysql.makeConnection()
//        try c.execute("DROP TABLE IF EXISTS transaction")
//        try c.execute("CREATE TABLE transaction (name VARCHAR(64))")
//        try c.execute("INSERT INTO transaction VALUES (?)", [
//            "tommy"
//        ])
//
//        do {
//            try c.transaction {
//                // will succeed, but will be rolled back
//                try c.execute("UPDATE transaction SET name = 'Timmy'")
//
//                // malformed query, will throw
//                try c.execute("💉")
//            }
//
//            XCTFail("Transaction should have rethrown error.")
//
//        } catch {
//            if let tommy = try c.execute("SELECT * FROM transaction")[0] {
//                XCTAssertEqual(tommy["name"]?.string, "tommy", "Should have ROLLBACK")
//            } else {
//                XCTFail("There should be one entry.")
//            }
//        }
//    }
//
//    func testBlob() throws {
//        let conn = try mysql.makeConnection()
//        try conn.execute("DROP TABLE IF EXISTS blobs")
//        try conn.execute("CREATE TABLE blobs (raw BLOB)")
//        // collection of bytes that would break UTF8
//        let inputBytes = Node.bytes([0xc3, 0x28, 0xa0, 0xa1, 0xe2, 0x28, 0xa1, 0xe2, 0x82, 0x28, 0xf0, 0x28, 0x8c, 0xbc])
//        try conn.execute("INSERT INTO blobs VALUES (?)", [inputBytes])
//        let retrieved = try conn.execute("SELECT * FROM blobs")[0, "raw"]?.bytes ?? []
//        let expectation = inputBytes.bytes ?? []
//        XCTAssert(!retrieved.isEmpty)
//        XCTAssert(!expectation.isEmpty)
//        XCTAssertEqual(retrieved, expectation)
//    }
//
//    func testTimeout() throws {
//        let conn = try mysql.makeConnection()
//        XCTAssert(!conn.isClosed)
//
//        try conn.execute("SET session wait_timeout=1;")
//        XCTAssert(!conn.isClosed)
//
//        sleep(2)
//
//        do {
//            try conn.execute("SELECT @@version")
//        } catch let error as MySQLError
//            where
//                error.code == .serverLost ||
//                error.code == .serverGone ||
//                error.code == .serverLostExtended
//        {
//            XCTAssert(conn.isClosed)
//            // correct error
//        } catch {
//            XCTFail("Timeout test failed.")
//        }
//    }
//
//    func testLongtext() throws {
//        let conn = try mysql.makeConnection()
//        try conn.execute("DROP TABLE IF EXISTS items")
//        try conn.execute("CREATE TABLE `items` ( " +
//            "`id` int(10) unsigned NOT NULL AUTO_INCREMENT, " +
//            "`title` varchar(255) NOT NULL DEFAULT '', " +
//            "`imageUrl` varchar(255) NOT NULL DEFAULT '', " +
//            "`html` longtext NOT NULL, " +
//            "`isPrivate` tinyint(1) unsigned NOT NULL, " +
//            "`isBusiness` tinyint(1) unsigned NOT NULL, " +
//            "PRIMARY KEY (`id`)) " +
//            "ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8;")
//
//        try conn.execute("INSERT INTO `items` (`id`, `title`, `imageUrl`, `html`, `isPrivate`, `isBusiness`) " +
//            "VALUES (1, 'test1', '12A34264-E5F6-48D4-AB27-422C4FD03277_10.jpeg', '<p>html</p>', 1, 1)")
//
//        let retrieved = try conn.execute("SELECT * from items")
//        XCTAssertEqual(retrieved.array?.count ?? 0, 1)
//        XCTAssertEqual(retrieved[0, "id"], 1)
//        XCTAssertEqual(retrieved[0, "title"], "test1")
//        XCTAssertEqual(retrieved[0, "html"]?.bytes?.makeString(), "<p>html</p>")
//    }
//
//    func testPerformance() throws {
//        let conn = try mysql.makeConnection()
//        try conn.execute("DROP TABLE IF EXISTS things")
//        try conn.execute("CREATE TABLE things (stuff VARCHAR(255))")
//        let string = String(repeating: "a", count: 255)
//        for _ in 0..<65_536 {
//            try conn.execute("INSERT INTO things VALUES (?)", [string])
//        }
//
//        measure {
//            _ = try! conn.execute("SELECT * FROM things")
//        }
//    }
}
