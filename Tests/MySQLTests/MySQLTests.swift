import Async
import Dispatch
@testable import MySQL
import TCP
import XCTest

let poolQueue: DefaultEventLoop = try! DefaultEventLoop(label: "multi")

/// Requires a user with the username `vapor` and password `vapor` with permissions on the `vapor_test` database on localhost
class MySQLTests: XCTestCase {
    var connection: MySQLConnection!

    static let allTests = [
        ("testPreparedStatements", testPreparedStatements),
        ("testPreparedStatements2", testPreparedStatements2),
        ("testPreparedStatementFail",testPreparedStatementFail),
        ("testCreateUsersSchema", testCreateUsersSchema),
        ("testPopulateUsersSchema", testPopulateUsersSchema),
        ("testForEach", testForEach),
        ("testAll", testAll),
        ("testStream", testStream),
        ("testComplexModel", testComplexModel),
        ("testFailures", testFailures),
        ("testSingleValueDecoding", testSingleValueDecoding),
    ]
    
    override func setUp() {
        connection = try! MySQLConnection.makeConnection(
            hostname: "localhost",
            user: "root",
            password: nil,
            database: "vapor_test",
            on: poolQueue
        ).await(on: poolQueue)
        
        _ = try? connection.dropTables(named: "users").await(on: poolQueue)
        _ = try? connection.dropTables(named: "complex").await(on: poolQueue)
        _ = try? connection.dropTables(named: "test").await(on: poolQueue)
        _ = try? connection.dropTables(named: "articles").await(on: poolQueue)
    }

    func testPreparedStatements() throws {
        try testPopulateUsersSchema()

        let query = "SELECT * FROM users WHERE `username` = ?"

        let users = try connection.withPreparation(statement: query) { statement in
            return try statement.bind { binding in
                try binding.bind("Joannis")
            }.all(User.self)
        }.await(on: poolQueue)

        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.admin, false)
        XCTAssertEqual(users.first?.username, "Joannis")
    }
    
    func testPreparedStatementFail() throws {
        try testPopulateUsersSchema()
        
        let query = "SELECT * FROM users1 WHERE `username` = ?"
        
        XCTAssertThrowsError(try connection.withPreparation(statement: query) { statement in
            return try statement.bind { binding in
                try binding.bind("Joannis")
                }.all(User.self)
            }.await(on: poolQueue))
    }
    
//    func testPerformance() throws {
//        try testPopulateUsersSchema()
//        var futures = [Future<Void>]()
//
//        for _ in 0..<100_000 {
//            let future = self.connection.administrativeQuery("INSERT INTO users (username, admin) VALUES ('Joannis', true)")
//
//            futures.append(future)
//        }
//
//        try futures.flatten().await(on: poolQueue)
//    }
    
    func testPreparedStatements2() throws {
        try testPopulateUsersSchema()
        
        let query = "SELECT * FROM users WHERE `id` = ?"
        
        let users = try connection.withPreparation(statement: query) { statement in
            return try statement.bind { binding in
                try binding.bind(4) // Tanner
            }.all(User.self)
        }.await(on: poolQueue)
        
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.admin, true)
        XCTAssertEqual(users.first?.username, "Tanner")
    }
    
    func testCreateUsersSchema() throws {
        let table = Table(named: "users")
     
        table.schema.append(Table.Column(named: "id", type: .int32(length: nil), autoIncrement: true, primary: true, unique: true))
     
        table.schema.append(Table.Column(named: "username", type: .varChar(length: 32, binary: false), autoIncrement: false, primary: false, unique: false))
        
        table.schema.append(Table.Column(named: "admin", type: .uint8(length: 1)))
     
        try connection.createTable(table).await(on: poolQueue)
    }
    
    func testPopulateUsersSchema() throws {
        try testCreateUsersSchema()
     
        try connection.administrativeQuery("INSERT INTO users (username, admin) VALUES ('Joannis', false)").await(on: poolQueue)
        try connection.administrativeQuery("INSERT INTO users (username, admin) VALUES ('Jonas', false)").await(on: poolQueue)
        try connection.administrativeQuery("INSERT INTO users (username, admin) VALUES ('Logan', true)").await(on: poolQueue)
        try connection.administrativeQuery("INSERT INTO users (username, admin) VALUES ('Tanner', true)").await(on: poolQueue)
    }
    
    func testForEach() throws {
        try testPopulateUsersSchema()

        var iterator = ["Joannis", "Jonas", "Logan", "Tanner"].makeIterator()
        var count = 0

        try connection.forEach(User.self, in: "SELECT * FROM users") { user in
            XCTAssertEqual(user.username, iterator.next())
            count += 1
        }.await(on: poolQueue)

        XCTAssertEqual(count, 4)
    }

    func testAll() throws {
        try testPopulateUsersSchema()

        var iterator = ["Joannis", "Jonas", "Logan", "Tanner"].makeIterator()

        let users = try connection.all(User.self, in: "SELECT * FROM users").await(on: poolQueue)
        for user in users {
            XCTAssertEqual(user.username, iterator.next())
        }

        XCTAssertEqual(users.count, 4)
    }

    func testStream() throws {
        try testPopulateUsersSchema()

        var iterator = ["Joannis", "Jonas", "Logan", "Tanner"].makeIterator()
        var count = 0
        let promise = Promise<Int>()

        connection.forEach(User.self, in: "SELECT * FROM users") { user in
            XCTAssertEqual(user.username, iterator.next())
            count += 1

            if count == 4 {
                promise.complete(4)
            }
        }.catch { XCTFail("\($0)") }

        XCTAssertEqual(4, try promise.future.await(on: poolQueue))
    }

    func testComplexModel() throws {
        let table = Table(named: "complex")

        table.schema.append(Table.Column(named: "id", type: .uint8(length: nil), autoIncrement: true, primary: true, unique: true))

        table.schema.append(Table.Column(named: "number0", type: .float()))
        table.schema.append(Table.Column(named: "number1", type: .double()))
        table.schema.append(Table.Column(named: "i16", type: .int16()))
        table.schema.append(Table.Column(named: "ui16", type: .uint16()))
        table.schema.append(Table.Column(named: "i32", type: .int32()))
        table.schema.append(Table.Column(named: "ui32", type: .uint32()))
        table.schema.append(Table.Column(named: "i64", type: .int64()))
        table.schema.append(Table.Column(named: "ui64", type: .uint64()))

        do {
            try connection.createTable(table).await(on: poolQueue)

            try connection.administrativeQuery("INSERT INTO complex (number0, number1, i16, ui16, i32, ui32, i64, ui64) VALUES (3.14, 6.28, -5, 5, -10000, 10000, 5000, 0)").await(on: poolQueue)

            try connection.administrativeQuery("INSERT INTO complex (number0, number1, i16, ui16, i32, ui32, i64, ui64) VALUES (3.14, 6.28, -5, 5, -10000, 10000, 5000, 0)").await(on: poolQueue)
        } catch {
            debugPrint(error)
            XCTFail()
            throw error
        }

        let all = try connection.all(Complex.self, in: "SELECT * FROM complex").await(on: poolQueue)

        XCTAssertEqual(all.count, 2)

        guard let first = all.first else {
            XCTFail()
            return
        }

        XCTAssertEqual(first.number0, 3.14)
        XCTAssertEqual(first.number1, 6.28)
        XCTAssertEqual(first.i16, -5)
        XCTAssertEqual(first.ui16, 5)
        XCTAssertEqual(first.i32, -10_000)
        XCTAssertEqual(first.ui32, 10_000)
        XCTAssertEqual(first.i64, 5_000)
        XCTAssertEqual(first.ui64, 0)

        try connection.dropTable(named: "complex").await(on: poolQueue)
    }

    func testSingleValueDecoding() throws {
        try testPopulateUsersSchema()

        let tables = try connection.all(String.self, in: "SHOW TABLES").await(on: poolQueue)
        XCTAssert(tables.contains("users"))
    }

    func testFailures() throws {
        XCTAssertThrowsError(try connection.administrativeQuery("INSRT INTOO users (username) VALUES ('Exampleuser')").await(on: poolQueue))
        XCTAssertThrowsError(try connection.all(User.self, in: "SELECT * FORM users").await(on: poolQueue))
    }

    func testText() throws {
        let table = Table(named: "articles")

        table.schema.append(Table.Column(named: "id", type: .uint8(length: nil), autoIncrement: true, primary: true, unique: true))

        table.schema.append(Table.Column(named: "text", type: .text()))

        try connection.createTable(table).await(on: poolQueue)

        try connection.administrativeQuery("INSERT INTO articles (text) VALUES ('hello, world')").await(on: poolQueue)

        let articles = try connection.all(Article.self, in: "SELECT * FROM articles").await(on: poolQueue)
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles.first?.text, "hello, world")
    }

    func testDeleteRead() throws {
        try testPopulateUsersSchema()

        let users = connection.administrativeQuery("DELETE FROM users WHERE username LIKE 'Jo%'").flatMap(to: Int.self) { _ in
            return self.connection.all(User.self, in: "SELECT * FROM users").map(to: Int.self) { users in
                return users.count
            }
        }

        XCTAssertEqual(try users.await(on: poolQueue), 2)
    }
}

struct User: Decodable {
    var id: Int
    var username: String
    var admin: Bool
}

struct Article: Decodable {
    var id: Int
    var text: String
}

struct Complex: Decodable {
    var id: Int
    var number0: Float
    var number1: Double
    var i16: Int16
    var ui16: UInt16
    var i32: Int32
    var ui32: UInt32
    var i64: Int64
    var ui64: UInt64
}

struct Test: Decodable {
    var id: Int
    var num: Int
}
