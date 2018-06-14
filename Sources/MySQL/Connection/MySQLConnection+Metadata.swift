extension MySQLConnection {
    public struct Metadata {
        private let ok: MySQLPacket.OK
        
        public var affectedRows: UInt64 {
            return ok.affectedRows
        }
        
        public var lastInsertID: UInt64? {
            return ok.lastInsertID
        }
        
        public func lastInsertID<I>(as type: I.Type = I.self) -> I?
            where I: FixedWidthInteger
        {
            return lastInsertID.flatMap(numericCast)
        }
        
        init(_ ok: MySQLPacket.OK) {
            self.ok = ok
        }
    }
}
