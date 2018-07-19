import Debugging
import Foundation

/// Errors that can be thrown while working with MySQL.
public struct MySQLError: Debuggable {
    /// See `Debuggable`.
    public static let readableName = "MySQL Error"
    
    /// See `Debuggable`.
    public let identifier: String
    
    /// See `Debuggable`.
    public var reason: String
    
    /// See `Debuggable`.
    public var possibleCauses: [String]
    
    /// See `Debuggable`.
    public var suggestedFixes: [String]
    
    /// See `Debuggable`.
    public var documentationLinks: [String]
    
    /// See `Debuggable`.
    public var sourceLocation: SourceLocation?
    
    /// See `Debuggable`.
    public var stackTrace: [String]

    /// Create a new `MySQLError`.
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

    /// Creates a new MySQL parse error.
    static func parse(
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
