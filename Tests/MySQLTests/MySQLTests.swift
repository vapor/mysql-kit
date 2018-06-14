import Async
@testable import MySQL
import XCTest

class MySQLTests: XCTestCase {
    func testSimpleQuery() throws {
        let conn = try MySQLConnection.makeTest()
        defer { conn.close(done: nil) }
        let results = try conn.simpleQuery("SELECT @@version").wait()
        _ = try conn.simpleQuery("SELECT @@version").wait()
        _ = try conn.simpleQuery("SELECT @@version").wait()
        try XCTAssert(results[0].firstValue(forColumn: "@@version")?.decode(String.self).contains(".") == true)
    }

    func testQuery() throws {
        let conn = try MySQLConnection.makeTest()
        defer { conn.close(done: nil) }
        let results = try conn.query(.raw("SELECT CONCAT(?, ?) as test;", [
            "hello".convertToMySQLData(),
            "world".convertToMySQLData()
        ])).wait()
        try XCTAssertEqual(results[0].firstValue(forColumn: "test")?.decode(String.self), "helloworld")
        print(results)
    }

    func testInsert() throws {
        let client = try MySQLConnection.makeTest()
        defer { client.close(done: nil) }
        let dropResults = try client.simpleQuery("DROP TABLE IF EXISTS foos;").wait()
        XCTAssertEqual(dropResults.count, 0)
        let createResults = try client.simpleQuery("CREATE TABLE foos (id INT SIGNED, name VARCHAR(64));").wait()
        XCTAssertEqual(createResults.count, 0)
        let insertResults = try client.query(.raw("INSERT INTO foos VALUES (?, ?);", [-1, "vapor"])).wait()
        XCTAssertEqual(insertResults.count, 0)
        let selectResults = try client.query(.raw("SELECT * FROM foos WHERE name = ?;", ["vapor"])).wait()
        XCTAssertEqual(selectResults.count, 1)
        print(selectResults)
        try XCTAssertEqual(selectResults[0].firstValue(forColumn: "id")?.decode(Int.self), -1)
        try XCTAssertEqual(selectResults[0].firstValue(forColumn: "name")?.decode(String.self), "vapor")

        // test double parameterized query
        let selectResults2 = try client.query(.raw("SELECT * FROM foos WHERE name = ?;", ["vapor"])).wait()
        XCTAssertEqual(selectResults2.count, 1)
    }

    func testKitchenSink() throws {
        /// support
        struct KitechSinkColumn {
            let name: String
            let columnType: String
            let data: MySQLData
            let match: (MySQLData?, StaticString, UInt) throws -> ()
            init<T>(_ name: String, _ columnType: String, _ value: T) where T: MySQLDataConvertible & Equatable {
                self.name = name
                self.columnType = columnType
                data = value.convertToMySQLData()
                self.match = { data, file, line in
                    if let data = data {
                        let t = try T.convertFromMySQLData(data)
                        XCTAssertEqual(t, value, "\(name) \(T.self)", file: file, line: line)
                    } else {
                        XCTFail("Data null", file: file, line: line)
                    }
                }
            }
        }
        let tests: [KitechSinkColumn] = [
            .init("xchar", "CHAR(60)", "hello1"),
            .init("xvarchar", "VARCHAR(61)", "hello2"),
            .init("xtext", "TEXT(62)", "hello3"),
            .init("xbinary", "BINARY(6)", "hello4"),
            .init("xvarbinary", "VARBINARY(66)", "hello5"),
            .init("xbit", "BIT", 1),
            .init("xtinyint", "TINYINT(1)", 5),
            .init("xsmallint", "SMALLINT(1)", 252),
            .init("xvarcharnull", "VARCHAR(10)", String?.none),
            .init("xmediumint", "MEDIUMINT(1)", 1024),
            .init("xinteger", "INTEGER(1)", 1024293),
            .init("xbigint", "BIGINT(1)", 234234234),
            .init("name", "VARCHAR(10) NOT NULL", "vapor"),
        ]

        let client = try MySQLConnection.makeTest()
        defer { client.close(done: nil) }
        /// create table
        let columns = tests.map { test in
            return "`\(test.name)` \(test.columnType)"
        }.joined(separator: ", ")
        let dropResults = try client.simpleQuery("DROP TABLE IF EXISTS kitchen_sink;").wait()
        XCTAssertEqual(dropResults.count, 0)
        let createResults = try client.simpleQuery("CREATE TABLE kitchen_sink (\(columns));").wait()
        XCTAssertEqual(createResults.count, 0)

        /// insert data
        let placeholders = tests.map { _ in "?" }.joined(separator: ", ")
        let insertResults = try client.query(.raw("INSERT INTO kitchen_sink VALUES (\(placeholders));", tests.map { $0.data })).wait()
        XCTAssertEqual(insertResults.count, 0)

        // select data
        let selectResults = try client.query(.raw("SELECT * FROM kitchen_sink WHERE name = ?;", ["vapor"])).wait()
        XCTAssertEqual(selectResults.count, 1)
        print(selectResults)

        for test in tests {
            try test.match(selectResults[0].firstValue(forColumn: test.name), #file, #line)
        }
    }

    func testLargeValues() throws {
        func testSize(_ size: Int) throws {
            let client = try MySQLConnection.makeTest()
            defer { client.close(done: nil) }
            client.logger = nil // the output will be too big
            let dropResults = try client.simpleQuery("DROP TABLE IF EXISTS foos;").wait()
            XCTAssertEqual(dropResults.count, 0)
            let createResults = try client.simpleQuery("CREATE TABLE foos (id INT SIGNED, name LONGTEXT);").wait()

            let bigName = String(repeating: "v", count: size)
            XCTAssertEqual(createResults.count, 0)
            _ = try client.query(.raw("INSERT INTO foos VALUES (?, ?);", [1, bigName.convertToMySQLData()])).wait()
            let selectResults = try client.simpleQuery("SELECT * FROM foos;").wait()
            XCTAssertEqual(selectResults.count, 1)
            if let value = selectResults.first?.firstValue(forColumn: "name") {
                let fetched = try String.convertFromMySQLData(value)
                XCTAssertEqual(fetched.count, bigName.count)
            } else {
                XCTFail()
            }
        }
        /// 1-byte
        try testSize(0)
        try testSize(128)
        try testSize(250)

        /// 2-byte
        try testSize(251)
        try testSize(252)
        try testSize(65_535)
        try testSize(65_536)

        /// 3-byte
        try testSize(65_537)
        try testSize(1_000_000)
    }

    func testTimePrecision() throws {
        let time = Date().convertToMySQLTime()
        XCTAssertNotEqual(time.microsecond, 0)
        try XCTAssertEqual(
            Double(Date.convertFromMySQLTime(time).convertToMySQLTime().microsecond),
            Double(time.microsecond),
            accuracy: 5
        )
    }

    func testSaveEmoticonsUnicode() throws {
        let client = try MySQLConnection.makeTest()
        defer { client.close(done: nil) }
        let dropResults = try client.simpleQuery("DROP TABLE IF EXISTS emojis;").wait()
        XCTAssertEqual(dropResults.count, 0)
        let createResults = try client.simpleQuery("CREATE TABLE emojis (id INT SIGNED NOT NULL, description VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL);").wait()
        XCTAssertEqual(createResults.count, 0)
        let insertResults = try client.query(.raw("INSERT INTO emojis VALUES (?, ?);", [1, "🇧🇷 🔸 🎶 🆙 〽️ ❤️ 🎁 🕹 🚁 🚴‍♀️ 🌶 🌈 🐎 🤔"])).wait()
        XCTAssertEqual(insertResults.count, 0)
        let selectResults = try client.query(.raw("SELECT * FROM emojis WHERE description = ?;", ["🇧🇷 🔸 🎶 🆙 〽️ ❤️ 🎁 🕹 🚁 🚴‍♀️ 🌶 🌈 🐎 🤔"])).wait()
        XCTAssertEqual(selectResults.count, 1)
        print(selectResults)
        try XCTAssertEqual(selectResults[0].firstValue(forColumn: "id")?.decode(Int.self), 1)
        try XCTAssertEqual(selectResults[0].firstValue(forColumn: "description")?.decode(String.self), "🇧🇷 🔸 🎶 🆙 〽️ ❤️ 🎁 🕹 🚁 🚴‍♀️ 🌶 🌈 🐎 🤔")

        // test double parameterized query
        let selectResults2 = try client.query(.raw("SELECT * FROM emojis WHERE description = ?;", ["🇧🇷 🔸 🎶 🆙 〽️ ❤️ 🎁 🕹 🚁 🚴‍♀️ 🌶 🌈 🐎 🤔"])).wait()
        XCTAssertEqual(selectResults2.count, 1)
    }

    func testStringCharacterSet() throws {
        var characterSet = "latin1_swedish_ci"
        XCTAssertNotNil(MySQLCharacterSet(string: characterSet))
        characterSet = "utf8_general_ci"
        XCTAssertNotNil(MySQLCharacterSet(string: characterSet))
        characterSet = "binary"
        XCTAssertNotNil(MySQLCharacterSet(string: characterSet))
        characterSet = "utf8mb4_unicode_ci"
        XCTAssertNotNil(MySQLCharacterSet(string: characterSet))
        characterSet = "utf64_imaginary"
        XCTAssertNil(MySQLCharacterSet(string: characterSet))
    }

    func testDisconnect() throws {
        /*
         uncomment to test disconnect
         SHOW PROCESSLIST
         KILL <pid>
         
        let client = try MySQLConnection.makeTest()
        while true {
            let version = try client.simpleQuery("SELECT @@version").wait()
            print(version)
            sleep(1)
        }
        */
    }
    
    func testInsertMany() throws {
        let conn = try MySQLConnection.makeTest()
        defer { conn.close(done: nil) }
        
        try conn.drop(table: Planet.self).ifExists()
            .run().wait()
        try conn.drop(table: Galaxy.self).ifExists()
            .run().wait()
        
        try conn.create(table: Galaxy.self)
            .column(for: \.id, .bigint(nil, unsigned: false, zerofill: false), .notNull, .primaryKey(autoIncrement: true))
            .column(for: \.name, .varchar(64, nil, nil), .notNull)
            .run().wait()
        try conn.create(table: Planet.self)
            .column(for: \.id, .bigint(nil, unsigned: false, zerofill: false), .notNull, .primaryKey(autoIncrement: true))
            .column(for: \.name, .varchar(64, nil, nil), .notNull)
            .column(for: \.galaxyID, .bigint(nil, unsigned: false, zerofill: false), .notNull)
            .foreignKey(from: \.galaxyID, to: \Galaxy.id)
            .run().wait()
        
        var milkyWay = Galaxy(name: "Milky Way")
        try conn.insert(into: Galaxy.self).value(milkyWay)
            .run().wait()
        milkyWay.id = conn.lastMetadata?.lastInsertID()
        guard let milkyWayID = milkyWay.id else {
            XCTFail("No ID returned")
            return
        }
        
        try conn.insert(into: Planet.self)
            .value(Planet(name: "Earth", galaxyID: milkyWayID))
            .run().wait()
        
        try conn.insert(into: Planet.self)
            .value(Planet(name: "Venus", galaxyID: milkyWayID))
            .value(Planet(name: "Mars", galaxyID: milkyWayID))
            .run().wait()
    }

    func testURLParsing() throws {
        let databaseURL = "mysql://username:password@hostname.com:3306/database"
        let config = try MySQLDatabaseConfig(url: databaseURL)!
        XCTAssertEqual(config.hostname, "hostname.com")
        XCTAssertEqual(config.port, 3306)
        XCTAssertEqual(config.username, "username")
        XCTAssertEqual(config.password, "password")
        XCTAssertEqual(config.database, "database")
    }
    
    /// https://github.com/vapor/mysql/issues/164
    func testPreparedStatementOverload() throws {
        #if os(Linux) // slow test, only run on CI
        let conn = try MySQLConnection.makeTest()
        defer { conn.close(done: nil) }
        for _ in 1...17_000 {
            conn.logger = nil
            _ = try conn.query(.raw("SELECT @@version", [])).wait()
        }
        #endif
    }
    
    static let allTests = [
        ("testSimpleQuery", testSimpleQuery),
        ("testQuery", testQuery),
        ("testInsert", testInsert),
        ("testKitchenSink", testKitchenSink),
        ("testLargeValues", testLargeValues),
        ("testTimePrecision", testTimePrecision),
        ("testSaveEmoticonsUnicode", testSaveEmoticonsUnicode),
        ("testStringCharacterSet", testStringCharacterSet),
        ("testDisconnect", testDisconnect),
        ("testURLParsing", testURLParsing),
        ("testInsertMany", testInsertMany),
        ("testPreparedStatementOverload", testPreparedStatementOverload),
    ]
}

extension MySQLConnection {
    /// Creates a test event loop and psql client.
    static func makeTest() throws -> MySQLConnection {
        let transport: MySQLTransportConfig
        #if SSL_TESTS
        transport = .unverifiedTLS
        #else
        transport = .cleartext
        #endif
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let conn =  try MySQLConnection.connect(config: .init(
            hostname: "localhost",
            username: "vapor_username",
            password: "vapor_password",
            database: "vapor_database",
            characterSet: .utf8mb4_unicode_ci,
            transport: transport
        ), on: group) { error in
            XCTFail("\(error)")
        }.wait()
        conn.logger = DatabaseLogger(database: .mysql, handler: PrintLogHandler())
        return conn
    }
}

struct Planet: MySQLTable {
    var id: Int?
    var name: String
    var galaxyID: Int
    
    init(id: Int? = nil, name: String, galaxyID: Int) {
        self.id = id
        self.name = name
        self.galaxyID = galaxyID
    }
}

struct Galaxy: MySQLTable {
    var id: Int?
    var name: String
    init(id: Int? = nil, name: String) {
        self.id = id
        self.name = name
    }
}
