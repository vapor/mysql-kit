import Bits

/// Possible connection states.
enum MySQLConnectionState {
    /// This is a new connection that has not completed the MySQL handshake.
    case awaitingHandshake

    /// The handshake has been completed and server capabilities are received.
    case handshakeComplete(MySQLCapabilities)
}

/// Represents information about a single MySQL connection.
final class MySQLConnectionSession {
    /// The state of this connection.
    var state: MySQLConnectionState

    /// The next available sequence ID.
    var nextSequenceID: Byte {
        defer { incrementSequenceID() }
        return sequenceID
    }

    /// The current sequence ID.
    private var sequenceID: Byte

    /// Creates a new `MySQLConnectionSession`.
    init() {
        self.state = .awaitingHandshake
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
