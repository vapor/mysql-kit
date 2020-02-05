import Foundation

public struct MySQLDialect: SQLDialect {
    public init() {}

    public var name: String {
        "mysql"
    }

    public var identifierQuote: SQLExpression {
        return SQLRaw("`")
    }

    public func bindPlaceholder(at position: Int) -> SQLExpression {
        return SQLRaw("?")
    }

    public func literalBoolean(_ value: Bool) -> SQLExpression {
        switch value {
        case false:
            return SQLRaw("0")
        case true:
            return SQLRaw("1")
        }
    }

    public var autoIncrementClause: SQLExpression {
        return SQLRaw("AUTO_INCREMENT")
    }

    public var supportsAutoIncrement: Bool {
        true
    }

    public var enumSyntax: SQLEnumSyntax {
        .inline
    }

    public var triggerSyntax: SQLTriggerSyntax {
        return .init(create: [.supportsBody, .conditionRequiresParentheses, .supportsOrder])
    }
}
