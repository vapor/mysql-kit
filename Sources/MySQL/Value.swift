/**
    Represents the various types of data that MySQL
    rows can contain and that will be returned by the Database.
*/
public enum Value {
    case string(String)
    case int(Int)
    case uint(UInt)
    case double(Double)
    case null
    
    public var string: String? {
        switch self {
        case let .string(val):
            return val
        default:
            return nil
        }
    }
    
    public var int: Int? {
        switch self {
        case let .int(val):
            return val
        default:
            return nil
        }
    }
    
    public var uint: UInt? {
        switch self {
        case let .uint(val):
            return val
        default:
            return nil
        }
    }
    
    public var double: Double? {
        switch self {
        case let .double(val):
            return val
        default:
            return nil
        }
    }
    
    public var isNull: Bool {
        switch self {
        case .null:
            return true
        default:
            return false
        }
    }
    
}
