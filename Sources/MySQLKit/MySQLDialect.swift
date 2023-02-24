import enum Crypto.Insecure
import SQLKit
import Foundation

public struct MySQLDialect: SQLDialect {
    public init() {}
    
    public var name: String {
        "mysql"
    }
    
    public var identifierQuote: SQLExpression {
        return SQLRaw("`")
    }
    
    public var literalStringQuote: SQLExpression {
        return SQLRaw("'")
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

    public func customDataType(for dataType: SQLDataType) -> SQLExpression? {
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
    
    public func normalizeSQLConstraint(identifier: SQLExpression) -> SQLExpression {
        if let sqlIdentifier = identifier as? SQLIdentifier {
            return SQLIdentifier(Insecure.SHA1.hash(data: Data(sqlIdentifier.string.utf8)).hexRepresentation)
        } else {
            return identifier
        }
    }

    public var triggerSyntax: SQLTriggerSyntax {
        return .init(create: [.supportsBody, .conditionRequiresParentheses, .supportsOrder])
    }
    
    public var upsertSyntax: SQLUpsertSyntax {
        .mysqlLike
    }

    public var unionFeatures: SQLUnionFeatures {
        [.union, .unionAll, .explicitDistinct, .parenthesizedSubqueries]
    }
    
    public var sharedSelectLockExpression: SQLExpression? {
        SQLRaw("LOCK IN SHARE MODE")
    }
    
    public var exclusiveSelectLockExpression: SQLExpression? {
        SQLRaw("FOR UPDATE")
    }
}

fileprivate let hexTable: [UInt8] = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66]
extension Sequence where Element == UInt8 {
    fileprivate var hexRepresentation: String {
        .init(decoding: self.flatMap { [hexTable[Int($0 >> 4)], hexTable[Int($0 & 0xf)]] }, as: Unicode.ASCII.self)
    }
}
