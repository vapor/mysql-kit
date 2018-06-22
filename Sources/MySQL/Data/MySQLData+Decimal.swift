extension Decimal: MySQLDataTypeStaticRepresentable {
    /// See `MySQLDataTypeStaticRepresentable`.
    public static var mysqlDataType: MySQLDataType {
        /// https://github.com/apple/swift-corelibs-foundation/blob/master/Foundation/Decimal.swift#L567
        /// decimal has max string size of 200
        return .varchar(200)
    }
}

extension Decimal: MySQLDataConvertible {
    /// See `MySQLDataConvertible`.
    public func convertToMySQLData() -> MySQLData {
        return .init(string: self.description)
    }
    
    /// See `MySQLDataConvertible`.
    public static func convertFromMySQLData(_ mysqlData: MySQLData) throws -> Decimal {
        guard let decimal = try Decimal(string: String.convertFromMySQLData(mysqlData)) else {
            throw MySQLError(identifier: "decimal", reason: "Could not decode decimal from MySQLData: \(mysqlData).")
        }
        return decimal
    }
}
