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

    /// See `Extendable`
    public var extend: Extend

    /// Handles enqueued redis commands and responses.
    private let queue: QueueHandler<MySQLPacket, MySQLPacket>

    /// The channel
    private let channel: Channel

    /// If non-nil, will log queries.
    public var logger: DatabaseLogger?

    /// The current query running, if one exists.
    private var pipeline: Future<Void>

    /// Currently running `send(...)`.
    private var currentSend: Promise<Void>?

    /// Creates a new MySQL client with the provided MySQL packet queue and channel.
    init(queue: QueueHandler<MySQLPacket, MySQLPacket>, channel: Channel) {
        self.queue = queue
        self.channel = channel
        self.pipeline = Future.map(on: channel.eventLoop) { }
        self.extend = [:]
        self.isClosed = false

        // when the channel closes, set isClosed to true and fail any
        // currently running calls to `send(...)`.
        channel.closeFuture.always {
            self.isClosed = true
            if let current = self.currentSend {
                current.fail(error: closeError)
            }
        }
    }

    /// Sends `MySQLPacket` to the server.
    internal func send(_ messages: [MySQLPacket], onResponse: @escaping (MySQLPacket) throws -> Bool) -> Future<Void> {
        // if currentSend is not nil, previous send has not completed
        assert(currentSend == nil, "Attempting to call `send(...)` again before previous invocation has completed.")

        // if the connection is closed, fail immidiately
        guard !isClosed else {
            return eventLoop.newFailedFuture(error: closeError)
        }

        // create a new promise and store it
        let promise = eventLoop.newPromise(Void.self)
        currentSend = promise

        // cascade this enqueue to the newly created promise
        queue.enqueue(messages) { message in
            switch message {
            case .err(let err): throw err.makeError(source: .capture())
            default: return try onResponse(message)
            }
        }.cascade(promise: promise)

        // when the promise completes, remove the reference to it
        promise.futureResult.always { self.currentSend = nil }

        // return the promise's future result (same as `queue.enqueue`)
        return promise.futureResult
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

/// Error to throw if the connection has closed.
private let closeError = MySQLError(identifier: "closed", reason: "Connection is closed.", source: .capture())
