import Async
import Crypto
import DatabaseKit
import NIO
import Foundation

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
    func send(_ messages: [MySQLPacket], onResponse: @escaping (MySQLPacket) throws -> Bool) -> Future<Void> {
        return queue.enqueue(messages) { message in
            switch message {
            case .err(let err): throw err.makeError(source: .capture())
            default: return try onResponse(message)
            }
        }
    }

    /// Closes this client.
    public func close() {
        channel.close(promise: nil)
    }
}
