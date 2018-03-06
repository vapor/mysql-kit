import Debugging
import Foundation

/// Errors that can be thrown while working with MySQL.
public struct MySQLError: Debuggable {
    public static let readableName = "MySQL Error"
    public let identifier: String
    public var reason: String
    public var sourceLocation: SourceLocation?
    public var stackTrace: [String]
    public var possibleCauses: [String]
    public var suggestedFixes: [String]

    /// Create a new TCP error.
    public init(
        identifier: String,
        reason: String,
        possibleCauses: [String] = [],
        suggestedFixes: [String] = [],
        source: SourceLocation
    ) {
        self.identifier = identifier
        self.reason = reason
        self.sourceLocation = source
        self.stackTrace = MySQLError.makeStackTrace()
        self.possibleCauses = possibleCauses
        self.suggestedFixes = suggestedFixes
    }

    public static func parse(_ identifier: String, source: SourceLocation) -> MySQLError {
        return MySQLError(identifier: "parse.\(identifier)", reason: "Could not parse MySQL packet.", source: source)
    }
}

func VERBOSE(_ string: @autoclosure () -> (String)) {
    #if VERBOSE
    print("[VERBOSE] [MySQL] \(string())")
    #endif
}
