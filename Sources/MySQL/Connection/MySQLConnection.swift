import Async
import Core
import Crypto
import DatabaseKit
import NIO
import Service

/// A MySQL frontend client.
public final class MySQLConnection: BasicWorker, DatabaseConnection {
    /// See `Worker`.
    public var eventLoop: EventLoop {
        return channel.eventLoop
    }

    /// See `DatabaseConnection`.
    public var isClosed: Bool

    /// Handles enqueued redis commands and responses.
    private let queue: QueueHandler<MySQLPacket, MySQLPacket>

    /// The channel
    private let channel: Channel

    /// If non-nil, will log queries.
    public var logger: DatabaseLogger?

    /// The current query running, if one exists.
    private var pipeline: Future<Void>

    /// See `Extendable.extend`
    public var extend: Extend

    /// Creates a new MySQL client with the provided MySQL packet queue and channel.
    init(queue: QueueHandler<MySQLPacket, MySQLPacket>, channel: Channel) {
        self.queue = queue
        self.channel = channel
        self.pipeline = Future.map(on: channel.eventLoop) { }
        self.extend = [:]
        self.isClosed = false
        channel.closeFuture.always {
            self.isClosed = true
        }
    }

    /// Sends `MySQLPacket` to the server.
    internal func send(_ messages: [MySQLPacket], onResponse: @escaping (MySQLPacket) throws -> Bool) -> Future<Void> {
        guard !isClosed else {
            let error = MySQLError(identifier: "closed", reason: "Connection is closed.", source: .capture())
            return eventLoop.newFailedFuture(error: error)
        }
        return queue.enqueue(messages) { message in
            switch message {
            case .err(let err): throw err.makeError(source: .capture())
            default: return try onResponse(message)
            }
        }
    }

    /// Submits an async task to be pipelined.
    internal func operation(_ work: @escaping () -> Future<Void>) -> Future<Void> {
        /// perform this work when the current pipeline future is completed
        let new = pipeline.then(work)

        /// append this work to the pipeline, discarding errors as the pipeline
        //// does not care about them
        pipeline = new.catchMap { err in
            return ()
        }

        /// return the newly enqueued work's future result
        return new
    }

    /// Closes this client.
    public func close() {
        channel.close(promise: nil)
    }
}
