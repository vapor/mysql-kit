import Async
@testable import MySQL
import SQLBenchmark
import XCTest

class MySQLTests: XCTestCase {
    func testBenchmark() throws {
        let conn = try MySQLConnection.makeTest()
        let benchmarker = SQLBenchmarker(on: conn)
        try benchmarker.run()
    }
    
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
        let results = try conn.raw("SELECT CONCAT(?, ?) as test;").bind("hello").bind("world").all().wait()
        print(results)
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
        let insertResults = try client.raw("INSERT INTO foos VALUES (?, ?);").bind(-1).bind("vapor").all().wait()
        XCTAssertEqual(insertResults.count, 0)
        let selectResults = try client.raw("SELECT * FROM foos WHERE name = ?;").bind("vapor").all().wait()
        XCTAssertEqual(selectResults.count, 1)
        print(selectResults)
        try XCTAssertEqual(selectResults[0].firstValue(forColumn: "id")?.decode(Int.self), -1)
        try XCTAssertEqual(selectResults[0].firstValue(forColumn: "name")?.decode(String.self), "vapor")

        // test double parameterized query
        let selectResults2 = try client.raw("SELECT * FROM foos WHERE name = ?;").bind("vapor").all().wait()
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
        let insertResults = try client.raw("INSERT INTO kitchen_sink VALUES (\(placeholders));").binds(tests.map { $0.data }).all().wait()
        XCTAssertEqual(insertResults.count, 0)

        // select data
        let selectResults = try client.raw("SELECT * FROM kitchen_sink WHERE name = ?;").bind("vapor").all().wait()
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
            _ = try client.raw("INSERT INTO foos VALUES (?, ?);").bind(1).bind(bigName).all().wait()
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
 
    func testDateBefore1970() throws {
        let time = Date(timeIntervalSince1970: 1.1).convertToMySQLTime()
        let time2 = Date(timeIntervalSince1970: -1.1).convertToMySQLTime()
        
        XCTAssert(time.microsecond == UInt32(100000))
        XCTAssert(time2.microsecond == UInt32(100000))
    }

    func testSaveEmoticonsUnicode() throws {
        let client = try MySQLConnection.makeTest()
        defer { client.close(done: nil) }
        let dropResults = try client.simpleQuery("DROP TABLE IF EXISTS emojis;").wait()
        XCTAssertEqual(dropResults.count, 0)
        let createResults = try client.simpleQuery("CREATE TABLE emojis (id INT SIGNED NOT NULL, description VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL);").wait()
        XCTAssertEqual(createResults.count, 0)
        let insertResults = try client.raw("INSERT INTO emojis VALUES (?, ?);").binds([1, "🇧🇷 🔸 🎶 🆙 〽️ ❤️ 🎁 🕹 🚁 🚴‍♀️ 🌶 🌈 🐎 🤔"]).all().wait()
        XCTAssertEqual(insertResults.count, 0)
        let selectResults = try client.raw("SELECT * FROM emojis WHERE description = ?;").binds(["🇧🇷 🔸 🎶 🆙 〽️ ❤️ 🎁 🕹 🚁 🚴‍♀️ 🌶 🌈 🐎 🤔"]).all().wait()
        XCTAssertEqual(selectResults.count, 1)
        print(selectResults)
        try XCTAssertEqual(selectResults[0].firstValue(forColumn: "id")?.decode(Int.self), 1)
        try XCTAssertEqual(selectResults[0].firstValue(forColumn: "description")?.decode(String.self), "🇧🇷 🔸 🎶 🆙 〽️ ❤️ 🎁 🕹 🚁 🚴‍♀️ 🌶 🌈 🐎 🤔")

        // test double parameterized query
        let selectResults2 = try client.raw("SELECT * FROM emojis WHERE description = ?;").binds(["🇧🇷 🔸 🎶 🆙 〽️ ❤️ 🎁 🕹 🚁 🚴‍♀️ 🌶 🌈 🐎 🤔"]).all().wait()
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
        
        defer {
            try? conn.drop(table: Planet.self).ifExists()
                .run().wait()
            try? conn.drop(table: Galaxy.self).ifExists()
                .run().wait()
        }
        
        try conn.create(table: Galaxy.self)
            .column(for: \Galaxy.id, type: .bigint(nil, unsigned: false, zerofill: false), .notNull, .primaryKey(default: .autoIncrement))
            .column(for: \Galaxy.name, type: .varchar(64), .notNull)
            .run().wait()
        try conn.create(table: Planet.self)
            .column(for: \Planet.id, type: .bigint(nil, unsigned: false, zerofill: false), .notNull, .primaryKey(default: .autoIncrement))
            .column(for: \Planet.name, type: .varchar(64), .notNull)
            .column(for: \Planet.galaxyID, type: .bigint(nil, unsigned: false, zerofill: false), .notNull, .references(\Galaxy.id))
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
            _ = try conn.raw("SELECT @@version").all().wait()
        }
        #endif
    }
    
    func testColumnAfter() throws {
        let conn = try MySQLConnection.makeTest()
        
        let builder = conn.alter(table: Galaxy.self)
            .column(for: \Galaxy.name)
            .order(\Galaxy.name, after: \Galaxy.id)
        
        var binds: [Encodable] = []
        let sql = builder.query.serialize(&binds)
        XCTAssertEqual(sql, "ALTER TABLE `Galaxy` ADD COLUMN `name` VARCHAR(255) NOT NULL AFTER `id`")
    }
    
    func testDecimalPrecision() throws {
        struct DecimalTest: MySQLTable {
            var num: Decimal
        }
        
        let conn = try MySQLConnection.makeTest()
        defer {
            try? conn.drop(table: DecimalTest.self).ifExists().run().wait()
        }
        try conn.create(table: DecimalTest.self)
            .column(for: \DecimalTest.num)
            .run().wait()
        
        let a = DecimalTest(num: .init(sign: .plus, exponent: 80, significand: 1.0))
        try conn.insert(into: DecimalTest.self).value(a)
            .run().wait()
        
        let b = try conn.select()
            .all().from(DecimalTest.self)
            .all(decoding: DecimalTest.self).wait()
        XCTAssertEqual(b.first?.num, a.num)
    }
    
    // https://github.com/vapor/mysql/issues/196
    func testZeroRowSelect() throws {
        struct Control: SQLTable {
            static let sqlTableIdentifierString = "controls"
            var id: String
            var user: String
        }
        let conn = try MySQLConnection.makeTest()
        try conn.drop(table: Control.self).ifExists().run().wait()
        try conn.create(table: Control.self)
            .column(for: \Control.id)
            .column(for: \Control.user)
            .run().wait()
        
        let res1 = try conn.simpleQuery("SELECT * FROM controls WHERE user = 'foo'").wait()
        XCTAssertEqual(res1.count, 0)
        let res2 = try conn.simpleQuery("SELECT * FROM controls WHERE user = 'foo'").wait()
        XCTAssertEqual(res2.count, 0)
    }
    
    static let allTests = [
        ("testBenchmark", testBenchmark),
        ("testSimpleQuery", testSimpleQuery),
        ("testQuery", testQuery),
        ("testInsert", testInsert),
        ("testKitchenSink", testKitchenSink),
        ("testLargeValues", testLargeValues),
        ("testTimePrecision", testTimePrecision),
        ("testDateBefore1970", testDateBefore1970),
        ("testSaveEmoticonsUnicode", testSaveEmoticonsUnicode),
        ("testStringCharacterSet", testStringCharacterSet),
        ("testDisconnect", testDisconnect),
        ("testURLParsing", testURLParsing),
        ("testInsertMany", testInsertMany),
        ("testPreparedStatementOverload", testPreparedStatementOverload),
        ("testColumnAfter", testColumnAfter),
        ("testDecimalPrecision", testDecimalPrecision),
        ("testZeroRowSelect", testZeroRowSelect),
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
        ), on: group).wait()
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
