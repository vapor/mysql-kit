/**
 A list of MySQL Error codes that
 can be thrown from calls to `Database`.
 */
public enum MySQLError: UInt32 {
    case unknownError
    case crServerGoneError = 2006
    case crServerLost = 2013
    case crCommandsOutOfSync = 2014
}

extension MySQLError {
    static func isServerGone(errorCode: UInt32) -> Bool {
        return [
            self.crServerGoneError.rawValue,
            self.crServerLost.rawValue,
            self.crCommandsOutOfSync.rawValue
        ].contains(errorCode)
    }
}
