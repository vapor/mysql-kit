import Debugging
import Foundation

/// Errors that can be thrown while working with MySQL.
public struct MySQLError: Debuggable {
    public static let readableName = "MySQL Error"
    public let identifier: String
    public var reason: String
    public var possibleCauses: [String]
    public var suggestedFixes: [String]
    public var documentationLinks: [String]
    public var sourceLocation: SourceLocation?
    public var stackTrace: [String]

    /// Create a new TCP error.
    public init(
        identifier: String,
        reason: String,
        possibleCauses: [String] = [],
        suggestedFixes: [String] = [],
        documentationLinks: [String] = [],
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.identifier = identifier
        self.reason = reason
        self.possibleCauses = possibleCauses
        self.suggestedFixes = suggestedFixes
        self.documentationLinks = documentationLinks
        self.sourceLocation = .init(file: file, function: function, line: line, column: column, range: nil)
        self.stackTrace = MySQLError.makeStackTrace()
    }

    public static func parse(
        _ identifier: String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) -> MySQLError {
        return MySQLError(identifier: "parse.\(identifier)", reason: "Could not parse MySQL packet.", file: file, function: function, line: line, column: column)
    }
}

func ERROR(_ string: @autoclosure () -> (String)) {
    print("[ERROR] [MySQL] \(string())")
}

func VERBOSE(_ string: @autoclosure () -> (String)) {
    #if VERBOSE
    print("[VERBOSE] [MySQL] \(string())")
    #endif
}
