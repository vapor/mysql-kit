/// An optional fsp value in the range from 0 to 6 may be given to specify fractional seconds precision.
/// A value of 0 signifies that there is no fractional part. If omitted, the default precision is 0.
public struct MySQLFractionalSecondsPrecision: Equatable, ExpressibleByIntegerLiteral {
    /// Raw value.
    public let value: UInt8
    
    /// Creates a new `MySQLFractionalSecondsPrecision`.
    public init?(_ value: UInt8) {
        switch value {
        case 0...6: self.value = value
        default: return nil
        }
    }
    
    /// See `ExpressibleByIntegerLiteral`.
    public init(integerLiteral value: UInt8) {
        guard let fsp = MySQLFractionalSecondsPrecision(value) else {
            fatalError("Invalid FSP value.")
        }
        self = fsp
    }
}
