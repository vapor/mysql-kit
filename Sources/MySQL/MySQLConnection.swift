import Async
import Crypto
import DatabaseKit
import NIO

/// A MySQL frontend client.
public final class MySQLConnection: BasicWorker, DatabaseConnection {
    /// See `Worker.eventLoop`
    public var eventLoop: EventLoop {
        return channel.eventLoop
    }

    /// Handles enqueued redis commands and responses.
    private let queue: QueueHandler<MySQLPacket, MySQLPacket>

    /// The channel
    private let channel: Channel

    /// Creates a new MySQL client with the provided MySQL packet queue and channel.
    init(queue: QueueHandler<MySQLPacket, MySQLPacket>, channel: Channel) {
        self.queue = queue
        self.channel = channel
    }

    /// Sends `MySQLPacket` to the server.
    func send(_ messages: [MySQLPacket], onResponse: @escaping (MySQLPacket) throws -> ()) -> Future<Void> {
        var error: Error?
        return queue.enqueue(messages) { message in
            print(message)
            switch message {
//            case .readyForQuery:
//                if let e = error { throw e }
//                return true
//            case .error(let e): error = e
//            case .notice(let n): print(n)
            default: try onResponse(message)
            }
            return false // request until ready for query
        }
    }

    /// Sends `PostgreSQLMessage` to the server.
    func send(_ message: [MySQLPacket]) -> Future<[MySQLPacket]> {
        var responses: [MySQLPacket] = []
        return send(message) { response in
            responses.append(response)
        }.map(to: [MySQLPacket].self) {
            return responses
        }
    }

    /// Authenticates the `PostgreSQLClient` using a username with no password.
    public func authenticate(username: String, database: String, password: String? = nil) -> Future<Void> {
        return queue.enqueue([]) { message in
            switch message {
            case .handshakev10(let handshake):
                return true
            default: throw MySQLError(identifier: "handshake", reason: "Unsupported message encountered during handshake: \(message).", source: .capture())
            }
        }.flatMap(to: Void.self) {
            let response = MySQLHandshakeResponse41(
                capabilities: [
                    CLIENT_PROTOCOL_41,
                    CLIENT_PLUGIN_AUTH,
                    CLIENT_SECURE_CONNECTION,
                    CLIENT_CONNECT_WITH_DB,
                    CLIENT_DEPRECATE_EOF
                ],
                maxPacketSize: 1_073_741_824,
                characterSet: 0x08,
                username: username,
                authResponse: "",
                database: database,
                authPluginName: "mysql_native_password"
            )
            return self.queue.enqueue([.handshakeResponse41(response)]) { message in
                print("after res: \(message)")
                return false
            }
        }
    }

    /// Closes this client.
    public func close() {
        channel.close(promise: nil)
    }
}

