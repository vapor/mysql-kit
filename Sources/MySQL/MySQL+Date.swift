import Foundation

public enum MySQLDateError {
    case invalidDate
}

extension Date {
    public init(mysql date: String) throws {
        guard let date = dateFormatter.date(from: date) else {
            throw MySQLDateError.invalidDate
        }
        
        self = date
    }
    
    public var mysql: String {
        return dateFormatter.string(from: self)
    }
}

private var _df: DateFormatter?
private var dateFormatter: DateFormatter {
    if let df = _df {
        return df
    }
    
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd HH:mm:ss"
    _df = df
    return df
}
