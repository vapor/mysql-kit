import XCTest

@testable import MySQL

class DateTests: XCTestCase {
    static let allTests = [
        ("testMySQLDateInit", testMySQLDateInit),
        ("testMySQLDateInitFailed", testMySQLDateInitFailed),
    ]
    
    func testMySQLDateInit() {
        let mysqlDateString = "2003-09-15 10:05:00"
        
        do {
            _ = try Date(mysql: mysqlDateString)
        } catch {
            XCTFail("Init failed: \(error)")
        }
    }
    
    func testMySQLDateInitFailed() {
        let malformedMysqlDateString = "2003-09-110:05:00"
        
        do {
            _ = try Date(mysql: malformedMysqlDateString)
            XCTFail("Init should have thrown")
        } catch MySQLDateError.invalidDate {
            // success
        } catch {
            XCTFail("Expected `MySQLDateError.invalidDate` caught `\(error)`")
        }
    }
}
