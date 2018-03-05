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
    public var state: MySQLConnectionState

    /// Creates a new `MySQLConnectionSession`.
    init() {
        self.state = .awaitingHandshake
    }
}
