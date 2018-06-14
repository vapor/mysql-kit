extension MySQLQuery.Expression {
    public enum Literal: Equatable {
        case numeric(String)
        case string(String)
        case blob(Data)
        case null
        case bool(Bool)
        case currentTime
        case currentDate
        case currentTimestamp
    }
}

extension MySQLQuery.Expression.Literal: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension MySQLQuery.Expression.Literal: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .numeric(value.description)
    }
}

extension MySQLQuery.Expression.Literal: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .numeric(value.description)
    }
}

extension MySQLQuery.Expression.Literal: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension MySQLSerializer {
    func serialize(_ literal: MySQLQuery.Expression.Literal) -> String {
        switch literal {
        case .numeric(let string): return string
        case .string(let string): return "'" + string + "'"
        case .blob(let blob): return "0x" + blob.hexEncodedString()
        case .null: return "NULL"
        case .bool(let bool): return bool.description.uppercased()
        case .currentTime: return "CURRENT_TIME"
        case .currentDate: return "CURRENT_DATE"
        case .currentTimestamp: return "CURRENT_TIMESTAMP"
        }
    }
}
