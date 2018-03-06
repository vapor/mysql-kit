import Bits

/// COM_STMT_EXECUTE asks the server to execute a prepared statement as identified by stmt-id.
///
/// It sends the values for the placeholders of the prepared statement (if it contained any) in Binary Protocol Value form.
/// The type of each parameter is made up of two bytes:
/// - the type as in Protocol::ColumnType
/// - a flag byte which has the highest bit set if the type is unsigned [80]
///
/// The num-params used for this packet has to match the num_params of the COM_STMT_PREPARE_OK of the corresponding prepared statement.
///
/// The server returns a COM_STMT_EXECUTE Response.
///
/// https://dev.mysql.com/doc/internals/en/com-stmt-execute.html#packet-COM_STMT_EXECUTE
struct MySQLComStmtExecute {
    /// 1              [17] COM_STMT_EXECUTE
    var statementID: UInt32

    /// 1              flags
    var flags: Byte
}
