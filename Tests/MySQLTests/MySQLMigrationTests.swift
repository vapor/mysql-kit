import Async
@testable import MySQL
import SQLBenchmark
import XCTest

class MySQLAlterTableTests: XCTestCase {

    func testDropOneColumn() throws {
        let client = try MySQLConnection.makeTest()
        defer { client.close(done: nil) }
        let dropResults = try client.simpleQuery("DROP TABLE IF EXISTS foos;").wait()
        XCTAssertEqual(dropResults.count, 0)
        let createResults = try client.simpleQuery("CREATE TABLE foos (id INT SIGNED, name VARCHAR(64));").wait()
        XCTAssertEqual(createResults.count, 0)
        let insertResults = try client.raw("INSERT INTO foos VALUES (?, ?);").bind(-1).bind("vapor").all().wait()
        XCTAssertEqual(insertResults.count, 0)

        let preSelectResults = try client.raw("SELECT * FROM foos;").all().wait()
        XCTAssertEqual(preSelectResults.count, 1)
        XCTAssertEqual(preSelectResults[0].count, 2) // 2 columns

        let tableId = MySQLTableIdentifier(stringLiteral: "foos");
        var migration = MySQLAlterTable(table: tableId)
        migration.deleteColumns = [
            MySQLColumnIdentifier.column(MySQLTableIdentifier(stringLiteral: "foos"), MySQLIdentifier.init("name"))
        ]
        
        var binds: [Encodable] = []
        let sql = migration.serialize(&binds)
        let migrationResults = try client.raw(sql).all().wait()
        XCTAssertEqual(migrationResults.count, 0)
        
        let postSelectResults = try client.raw("SELECT * FROM foos;").all().wait()
        XCTAssertEqual(postSelectResults.count, 1)
        XCTAssertEqual(postSelectResults[0].count, 1) // 1 column
        XCTAssertEqual(postSelectResults[0].keys.first!, MySQLColumn(table: "foos", name: "id"))
    }
    
    func testDropColumnMultipleColumns() throws {
        let client = try MySQLConnection.makeTest()
        defer { client.close(done: nil) }
        let dropResults = try client.simpleQuery("DROP TABLE IF EXISTS foos;").wait()
        XCTAssertEqual(dropResults.count, 0)
        let createResults = try client.simpleQuery("CREATE TABLE foos (id INT SIGNED, name1 VARCHAR(64), name2 VARCHAR(64));").wait()
        XCTAssertEqual(createResults.count, 0)
        let insertResults = try client.raw("INSERT INTO foos VALUES (?, ?, ?);").bind(-1).bind("vapor1").bind("vapor2").all().wait()
        XCTAssertEqual(insertResults.count, 0)
        
        let preSelectResults = try client.raw("SELECT * FROM foos;").all().wait()
        XCTAssertEqual(preSelectResults.count, 1)
        XCTAssertEqual(preSelectResults[0].count, 3) // 3 columns
        
        let tableId = MySQLTableIdentifier(stringLiteral: "foos");
        var migration = MySQLAlterTable(table: tableId)
        migration.deleteColumns = [
            MySQLColumnIdentifier.column(MySQLTableIdentifier(stringLiteral: "foos"), MySQLIdentifier.init("name1")),
            MySQLColumnIdentifier.column(MySQLTableIdentifier(stringLiteral: "foos"), MySQLIdentifier.init("name2"))
        ]
        
        var binds: [Encodable] = []
        let sql = migration.serialize(&binds)
        let migrationResults = try client.raw(sql).all().wait()
        XCTAssertEqual(migrationResults.count, 0)
        
        let postSelectResults = try client.raw("SELECT * FROM foos;").all().wait()
        XCTAssertEqual(postSelectResults.count, 1)
        XCTAssertEqual(postSelectResults[0].count, 1) // 1 column
        XCTAssertEqual(postSelectResults[0].keys.first!, MySQLColumn(table: "foos", name: "id"))
    }
    
    static let allTests = [
        ("testDropOneColumn", testDropOneColumn),
        ("testDropColumnMultipleColumns", testDropColumnMultipleColumns),
    ]
}
