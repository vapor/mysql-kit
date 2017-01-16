import Foundation

public enum MySQLDateError: Swift.Error {
    /**
        Date wasn't a proper DATETIME-formatted String.
     */
    case invalidDate
}

extension Date {
    /**
        Instantiates a `Date` from a MySQL DATETIME-formatted String.
     
        - Parameters:
            - mysql: yyyy-MM-dd HH:mm:ss
     */
    public init(mysql date: String) throws {
        guard let date = dateFormatter.date(from: date) else {
            throw MySQLDateError.invalidDate
        }
        
        self = date
    }
    
    /**
        A MySQL DATETIME formatted String.
     */
    public var mysql: String {
        return dateFormatter.string(from: self)
    }
}

// DateFormatter init is slow, need to reuse
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
