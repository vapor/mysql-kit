import Async
import Bits
import Foundation

/// A statement that has been bound and is ready for execution
public final class BoundStatement {
    /// The statement to bind to
    let statement: PreparedStatement

    /// The amount of bound parameters
    var boundParameters = 0

    /// The internal cache used to build up the header and null map of the query
    var header: [UInt8] = [
        0x17, // Header
        0,0,0,0, // statementId
        0, // flags
        1, 0, 0, 0 // iteration count (always 1)
    ]

    // Stores the bound parameters
    var parameterData = [UInt8]()

    /// Creates a new BoundStatemnt
    init(forStatement statement: PreparedStatement) {
        self.statement = statement

        header.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 1) { pointer in
                pointer.pointee = statement.statementID
            }
        }

        for _ in 0..<(statement.parameters.count + 7)/8 {
            header.append(0)
        }

        // Types are sent to the server
        header.append(1)
    }

    /// https://mariadb.com/kb/en/library/com_stmt_execute/
    ///
    /// Executes the bound statement
    ///
    /// TODO: Support cursors
    ///
    /// Flags:
    ///     0    no cursor
    ///     1    read only
    ///     2    cursor for update
    ///     4    scrollable cursor
    func execute(into stream: AnyInputStream<Row>) throws {
        if statement.executed {
            statement.reset()
        }
        
        guard boundParameters == statement.parameters.count else {
            throw MySQLError(.notEnoughParametersBound)
        }
        
        statement.executed = true
        
        let context = StreamState.QueryContext(output: stream, binary: self.statement.statementID)

        statement.connection.stateMachine.executor.push(.executePreparation(header + parameterData, context))
    }

    /// Fetched `count` more results from MySQL
    func getMore(count: UInt32, output: AnyInputStream<Row>) {
        let context = StreamState.QueryContext(output: output, binary: self.statement.statementID)
        
        statement.connection.stateMachine.executor.push(.getMore(count, context))
    }
}
