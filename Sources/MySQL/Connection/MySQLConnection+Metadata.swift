extension MySQLConnection {
    /// Query result metadata.
    ///
    ///     conn.lastMetadata?.affectedRows
    ///
    public struct Metadata {
        /// Root OK packet.
        private let ok: MySQLPacket.OK
        
        /// Number of affected rows from the last query.
        public var affectedRows: UInt64 {
            return ok.affectedRows
        }
        
        /// `AUTO_INCREMENT` insert ID from the last query (if exists).
        public var lastInsertID: UInt64? {
            return ok.lastInsertID
        }
        
        /// Casts the `lastInsertID` to a generic `FixedWidthInteger`.
        public func lastInsertID<I>(as type: I.Type = I.self) -> I?
            where I: FixedWidthInteger
        {
            return lastInsertID.flatMap(numericCast)
        }
        
        /// Creates a new query result metadata.
        init(_ ok: MySQLPacket.OK) {
            self.ok = ok
        }
    }
}
