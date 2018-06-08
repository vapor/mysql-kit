extension MySQLConnection {
    public struct Metadata {
        private let ok: MySQLPacket.OK
        
        public var affectedRows: UInt64 {
            return ok.affectedRows
        }
        
        public var lastInsertID: UInt64? {
            return ok.lastInsertID
        }
        
        init(_ ok: MySQLPacket.OK) {
            self.ok = ok
        }
    }
}
