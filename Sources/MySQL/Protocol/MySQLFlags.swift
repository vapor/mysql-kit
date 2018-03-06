protocol MySQLFlags: ExpressibleByIntegerLiteral {
    associatedtype RawIntegerType: FixedWidthInteger
    var raw: RawIntegerType { get set }
    init(raw: RawIntegerType)
}

extension MySQLFlags {
    init(integerLiteral value: RawIntegerType) {
        self.init(raw: value)
    }

    /// Returns true if the capability is enabled.
    func get(_ flag: Self) -> Bool {
        return raw & flag.raw > 0
    }

    /// Enables or disables a capability.
    mutating func set(_ capability: Self, to enabled: Bool) {
        if enabled {
            raw |= capability.raw
        } else {
            raw &= ~capability.raw
        }
    }
}
