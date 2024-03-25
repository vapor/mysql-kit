import enum Crypto.Insecure
import SQLKit
import Foundation

public struct MySQLDialect: SQLDialect {
    public init() {}
    
    public var name: String {
        "mysql"
    }
    
    public var identifierQuote: any SQLExpression {
        SQLRaw("`")
    }
    
    public var literalStringQuote: any SQLExpression {
        SQLRaw("'")
    }
    
    public func bindPlaceholder(at position: Int) -> any SQLExpression {
        SQLRaw("?")
    }

    public func literalBoolean(_ value: Bool) -> any SQLExpression {
        switch value {
        case false:
            return SQLRaw("0")
        case true:
            return SQLRaw("1")
        }
    }
    
    public var autoIncrementClause: any SQLExpression {
        SQLRaw("AUTO_INCREMENT")
    }

    public var supportsAutoIncrement: Bool {
        true
    }

    public var enumSyntax: SQLEnumSyntax {
        .inline
    }

    public func customDataType(for dataType: SQLDataType) -> (any SQLExpression)? {
        switch dataType {
        case .text:
            return SQLRaw("VARCHAR(255)")
        default:
            return nil
        }
    }

    public var alterTableSyntax: SQLAlterTableSyntax {
        .init(
            alterColumnDefinitionClause: SQLRaw("MODIFY COLUMN"),
            alterColumnDefinitionTypeKeyword: nil
        )
    }
    
    public func normalizeSQLConstraint(identifier: any SQLExpression) -> any SQLExpression {
        if let sqlIdentifier = identifier as? SQLIdentifier {
            return SQLIdentifier(Insecure.SHA1.hash(data: Data(sqlIdentifier.string.utf8)).hexRepresentation)
        } else {
            return identifier
        }
    }

    public var triggerSyntax: SQLTriggerSyntax {
        .init(create: [.supportsBody, .conditionRequiresParentheses, .supportsOrder], drop: [])
    }
    
    public var upsertSyntax: SQLUpsertSyntax {
        .mysqlLike
    }

    public var unionFeatures: SQLUnionFeatures {
        [.union, .unionAll, .explicitDistinct, .parenthesizedSubqueries]
    }
    
    public var sharedSelectLockExpression: (any SQLExpression)? {
        SQLRaw("LOCK IN SHARE MODE")
    }
    
    public var exclusiveSelectLockExpression: (any SQLExpression)? {
        SQLRaw("FOR UPDATE")
    }
    
    public func nestedSubpathExpression(in column: any SQLExpression, for path: [String]) -> (any SQLExpression)? {
        guard !path.isEmpty else { return nil }
        
        // N.B.: While MySQL has had the `->` and `->>` operators since 5.7.13, there are still implementations with
        // which they do not work properly (most notably AWS's Aurora 2.x), so we use the legacy functions instead.
        return SQLFunction("json_unquote", args:
            SQLFunction("json_extract", args: [
                column,
                SQLLiteral.string("$.\(path.joined(separator: "."))")
            ]
        ))
    }
}

fileprivate let hexTable: [UInt8] = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66]
extension Sequence where Element == UInt8 {
    fileprivate var hexRepresentation: String {
        .init(decoding: self.flatMap { [hexTable[Int($0 >> 4)], hexTable[Int($0 & 0xf)]] }, as: Unicode.ASCII.self)
    }
}
