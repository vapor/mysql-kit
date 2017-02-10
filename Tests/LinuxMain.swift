#if os(Linux)

import XCTest
@testable import MySQLTests

XCTMain([
    testCase(DateTests.allTests),
    testCase(MySQLTests.allTests),
])

#endif
