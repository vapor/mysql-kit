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
    func send(_ messages: [MySQLPacket], onResponse: @escaping (MySQLPacket) throws -> ()) -> Future<Void> {
        return queue.enqueue(messages) { message in
            switch message {
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

    public func simpleQuery(_ string: String) -> Future<[[String: String?]]> {
        var rows: [[String: String?]] = []
        return simpleQuery(string) { row in
            rows.append(row)
        }.map(to: [[String: String?]].self) {
            return rows
        }
    }

    public func simpleQuery(_ string: String, onRow: @escaping ([String: String?]) throws -> ()) -> Future<Void> {
        let comQuery = MySQLComQuery(query: string)
        var columns: [MySQLColumnDefinition41] = []
        var currentRow: [String: String?] = [:]
        return queue.enqueue([.comQuery(comQuery)]) { message in
            switch message {
            case .columnDefinition41(let col):
                columns.append(col)
                return false
            case .resultSetRow(let row):
                let col = columns[currentRow.keys.count]
                currentRow[col.name] = row.value
                if currentRow.keys.count >= columns.count {
                    try onRow(currentRow)
                    currentRow = [:]
                }
                return false
            case .ok, .eof: return true
            default: throw MySQLError(identifier: "simpleQuery", reason: "Unsupported message encountered during simple query: \(message).", source: .capture())
            }
        }
    }

    public func query(_ string: String, _ parameters: [String],  onRow: @escaping ([String: String?]) throws -> ()) -> Future<Void> {
        let comPrepare = MySQLComStmtPrepare(query: string)
        var ok: MySQLComStmtPrepareOK?
        var columns: [MySQLColumnDefinition41] = []
        return queue.enqueue([.comStmtPrepare(comPrepare)]) { message in
            print("AFTER PREPARE: \(message)")
            switch message {
            case .comStmtPrepareOK(let _ok):
                ok = _ok
                return false
            case .columnDefinition41(let col):
                let ok = ok!
                columns.append(col)
                if columns.count == ok.numColumns + ok.numParams {
                    return true
                } else {
                    return false
                }
            case .ok, .eof:
                // ignore ok and eof
                return false
            default: throw MySQLError(identifier: "query", reason: "Unsupported message encountered during prepared query: \(message).", source: .capture())
            }
        }.flatMap(to: Void.self) {
            let ok = ok!
            print(ok)
            let comExecute = MySQLComStmtExecute(
                statementID: ok.statementID,
                flags: 0x00, // which flags?
                values: [
                    MySQLBinaryValue(type: .MYSQL_TYPE_VARCHAR, isUnsigned: false, data: Data([0x03, 0x66, 0x6f, 0x6f])),
                    MySQLBinaryValue(type: .MYSQL_TYPE_VARCHAR, isUnsigned: false, data: Data([0x03, 0x66, 0x6e, 0x6f])),
                ]
            )
            return self.queue.enqueue([.comStmtExecute(comExecute)]) { message in
                print("AFTER EXECUTE: \(message)")
                switch message {
                case .binaryResultsetRow(let row):
                    print("got row")
                    return false
                case .columnDefinition41(let col):
                    print("got col")
                    return false
                case .ok, .eof:
                    // ignore ok and eof
                    print("GOT OK")
                    return true
                default: throw MySQLError(identifier: "query", reason: "Unsupported message encountered during prepared query: \(message).", source: .capture())
                }
            }
        }
    }

    /// Authenticates the `PostgreSQLClient` using a username with no password.
    public func authenticate(username: String, database: String, password: String? = nil) -> Future<Void> {
        var handshake: MySQLHandshakeV10?
        return queue.enqueue([]) { message in
            switch message {
            case .handshakev10(let _handshake):
                handshake = _handshake
                return true
            default: throw MySQLError(identifier: "handshake", reason: "Unsupported message encountered during handshake: \(message).", source: .capture())
            }
        }.flatMap(to: Void.self) {
            guard let handshake = handshake else {
                throw MySQLError(identifier: "handshake", reason: "Handshake required for auth response.", source: .capture())
            }
            let authPlugin = handshake.authPluginName ?? "none"
            let authResponse: Data
            switch authPlugin {
            case "mysql_native_password":
                guard let password = password else {
                    throw MySQLError(identifier: "password", reason: "Password required for auth plugin.", source: .capture())
                }
                guard handshake.authPluginData.count >= 20 else {
                    throw MySQLError(identifier: "salt", reason: "Server-supplied salt too short.", source: .capture())
                }
                let salt = Data(handshake.authPluginData[..<20])
                let passwordHash = SHA1.hash(password)
                let passwordDoubleHash = SHA1.hash(passwordHash)
                var hash = SHA1.hash(salt + passwordDoubleHash)
                for i in 0..<20 {
                    hash[i] = hash[i] ^ passwordHash[i]
                }
                authResponse = hash
            default: throw MySQLError(identifier: "authPlugin", reason: "Unsupported auth plugin: \(authPlugin)", source: .capture())
            }
            let response = MySQLHandshakeResponse41(
                capabilities: [
                    CLIENT_PROTOCOL_41,
                    CLIENT_PLUGIN_AUTH,
                    CLIENT_SECURE_CONNECTION,
                    CLIENT_CONNECT_WITH_DB,
                    CLIENT_DEPRECATE_EOF
                ],
                maxPacketSize: 1_024,
                characterSet: 0x21,
                username: username,
                authResponse: authResponse,
                database: database,
                authPluginName: authPlugin
            )
            return self.queue.enqueue([.handshakeResponse41(response)]) { message in
                switch message {
                case .ok(_): return true
                default: throw MySQLError(identifier: "handshake", reason: "Unsupported message encountered during handshake: \(message).", source: .capture())
                }
            }
        }
    }

    /// Closes this client.
    public func close() {
        channel.close(promise: nil)
    }
}

