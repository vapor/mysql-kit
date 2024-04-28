import MySQLNIO

/// Conforms `Optional` to `MySQLDataConvertible` for efficiency.
extension Optional: MySQLDataConvertible where Wrapped: MySQLDataConvertible {
    // See `MySQLDataConvertible.init?(mysqlData:)`.
    public init?(mysqlData: MySQLData) {
        if mysqlData.buffer != nil {
            guard let value = Wrapped.init(mysqlData: mysqlData) else {
                return nil
            }
            self = .some(value)
        } else {
            self = .none
        }
    }
    
    // See `MySQLDataConvertible.mysqlData`.
    public var mysqlData: MySQLData? {
        self == nil ? .null : self.flatMap(\.mysqlData)
    }
}
