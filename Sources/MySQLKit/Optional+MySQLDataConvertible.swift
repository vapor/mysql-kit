import MySQLNIO

extension Optional: MySQLDataConvertible where Wrapped: MySQLDataConvertible {
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
    
    public var mysqlData: MySQLData? {
        self == nil ? .null : self.flatMap(\.mysqlData)
    }
}
