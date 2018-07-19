import Bits

/// Represents information about a single MySQL connection.
final class MySQLPacketState {
    /// The state of this connection.
    var handshakeState: MySQLHandshakeState

    /// The state of queries and other functionality on this connection.
    var connectionState: MySQLConnectionState
    
    var eofState: MySQLEOFState

    /// The next available sequence ID.
    var nextSequenceID: Byte {
        defer { incrementSequenceID() }
        return sequenceID
    }

    /// The current sequence ID.
    private var sequenceID: Byte

    /// Creates a new `MySQLConnectionSession`.
    init() {
        self.handshakeState = .waiting
        self.connectionState = .none
        self.eofState = .none
        self.sequenceID = 0
    }

    /// Increments the sequence ID.
    func incrementSequenceID() {
        sequenceID = sequenceID &+ 1
    }

    /// Resets the sequence ID.
    func resetSequenceID() {
        sequenceID = 0
    }
}

/// Possible connection states.
enum MySQLHandshakeState {
    /// This is a new connection that has not completed the MySQL handshake.
    case waiting

    /// The handshake has been completed and server capabilities are received.
    case complete(MySQLCapabilities)
}

/// Possible states of a handshake-completed connection.
enum MySQLConnectionState {
    /// No special state.
    /// The connection should parse OK and ERR packets only.
    case none
    /// Performing a Text Protocol query.
    case text(MySQLTextProtocolState)
    /// Performing a Statement Protocol query.
    case statement(MySQLStatementProtocolState)
}

enum MySQLEOFState {
    case none
    case waiting
}

/// Connection states during a simple query aka Text Protocol.
/// https://dev.mysql.com/doc/internals/en/text-protocol.html
enum MySQLTextProtocolState {
    /// 14.6.4 COM_QUERY has been sent, awaiting response.
    case waiting
    /// parsing column_count * Protocol::ColumnDefinition packets
    case columns(columnCount: Int, remaining: Int)
    /// parsing One or more ProtocolText::ResultsetRow packets, each containing column_count values
    case rows(columnCount: Int, remaining: Int)
}

/// Connection states during a prepared query aka Statement Protocol.
/// https://dev.mysql.com/doc/internals/en/com-stmt-prepare-response.html
enum MySQLStatementProtocolState {
    /// COM_STMT_PREPARE_OK on success, ERR_Packet otherwise
    case waitingPrepare
    /// If num_params > 0 more packets will follow:
    case params(ok: MySQLComStmtPrepareOK, remaining: Int)
    case paramsDone(ok: MySQLComStmtPrepareOK, lastColumn: MySQLColumnDefinition41?)
    /// If num_columns > 0 more packets will follow:
    case columns(remaining: Int)
    case columnsDone(lastColumn: MySQLColumnDefinition41?)

    case waitingExecute
    case rowColumns(columns: [MySQLColumnDefinition41], remaining: Int)
    case rowColumnsDone(columns: [MySQLColumnDefinition41])
    /// ProtocolBinary::ResultsetRow until eof
    case rows(columns: [MySQLColumnDefinition41])
}
