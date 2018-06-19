public struct MySQLFunction: SQLFunction {
    public typealias Argument = GenericSQLFunctionArgument<MySQLExpression>
    
    public static func function(_ name: String, _ args: [Argument]) -> MySQLFunction {
        return .init(name: name, arguments: args)
    }
    
    public let name: String
    public let arguments: [Argument]
    
    public func serialize(_ binds: inout [Encodable]) -> String {
        return name + "(" + arguments.map { $0.serialize(&binds) }.joined(separator: ", ") + ")"
    }
}

extension SQLSelectExpression where Expression.Function == MySQLFunction {
    // custom
}
