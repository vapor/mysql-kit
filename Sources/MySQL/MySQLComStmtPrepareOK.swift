import Bits

/// 14.7.4.1 COM_STMT_PREPARE Response
///
/// If the COM_STMT_PREPARE succeeded, it sends a COM_STMT_PREPARE_OK
///
/// https://dev.mysql.com/doc/internals/en/com-stmt-prepare-response.html#packet-COM_STMT_PREPARE_OK
struct MySQLComStmtPrepareOK {
    /// statement_id (4) -- statement-id
    var statementID: UInt32

    /// num_columns (2) -- number of columns
    var numColumns: UInt16

    /// num_params (2) -- number of params
    var numParams: UInt16

    /// warning_count (2) -- number of warnings
    var warningCount: UInt16

    /// Parses a `MySQLComStmtPrepareOK` from the `ByteBuffer`.
    init(bytes: inout ByteBuffer) throws {
        let status = try bytes.requireInteger(as: Byte.self, source: .capture())
        guard status == 0x00 else {
            throw MySQLError(identifier: "prepareStatus", reason: "Prepare response has invalid status", source: .capture())
        }

        statementID = try bytes.requireInteger(endianness: .little, source: .capture())
        numColumns = try bytes.requireInteger(endianness: .little, source: .capture())
        numParams = try bytes.requireInteger(endianness: .little, source: .capture())

        /// reserved_1 (1) -- [00] filler
        let reserved_1 = try bytes.requireInteger(as: Byte.self, source: .capture())
        assert(reserved_1 == 0x00)

        warningCount = try bytes.requireInteger(endianness: .little, source: .capture())
    }
}
