import XCTest
import MySQL

extension MySQL.Database {
    static func makeTest() -> MySQL.Database {
        do {
            let mysql = try MySQL.Database(
                host: "127.0.0.1",
                user: "root",
                password: "",
                database: "test"
            )
            let connection = try mysql.makeConnection()
            try connection.execute("SELECT @@version")

            return mysql
        } catch {
            print()
            print()
            print("⚠️  MySQL Not Configured ⚠️")
            print()
            print("Error: \(error)")
            print()
            print("You must configure MySQL to run with the following configuration: ")
            print("    user: 'root'")
            print("    password: '' // (empty)")
            print("    host: '127.0.0.1'")
            print("    database: 'test'")
            print()

            print()

            XCTFail("Configure MySQL")
            fatalError("Configure MySQL")
        }
    }
}
