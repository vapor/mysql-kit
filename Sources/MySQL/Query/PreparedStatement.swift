import Async
import Bits
import Foundation

/// A single prepared statement that can be binded, executed, reset and closed
///
/// [Learn More →](https://docs.vapor.codes/3.0/databases/mysql/prepared-statements/)
public struct PreparedStatement {
    /// The internal statement ID
    let statementID: UInt32
    
    /// The connection this statment is bound to
    let stateMachine: MySQLStateMachine
    
    /// The parsed column definition
    var columns = [Field]()
    
    /// The required parameters to be bound
    var parameters = [Field]()
    
    /// Closes/cleans up this statement
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/databases/mysql/prepared-statements/)
    public func close() {
        stateMachine.executor.push(.closePreparation(statementID))
    }
    
    /// Resets this prepared statement to it's prepared state (rather than fetching/executed)
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/databases/mysql/prepared-statements/)
    public func reset()  {
        stateMachine.executor.push(.resetPreparation(statementID))
    }
    
    /// Executes the `closure` with the preparation binding statement
    ///
    /// The closure will be able to bind statements that ends up being bound and returned
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/databases/mysql/prepared-statements/)
    public func bind(run closure: @escaping ((PreparationBinding) throws -> ())) rethrows -> BoundStatement {
        let binding = PreparationBinding(forStatement: self)
        
        try closure(binding)
        
        return binding.boundStatement
    }
    
    /// Creates a new prepared statement from parsed data
    init(statementID: UInt32, columns: [Field], stateMachine: MySQLStateMachine, parameters: [Field]) {
        self.statementID = statementID
        self.columns = columns
        self.stateMachine = stateMachine
        self.parameters = parameters
    }
}

/// A binding context that is used to bind
///
/// [Learn More →](https://docs.vapor.codes/3.0/databases/mysql/prepared-statements/)
public final class PreparationBinding {
    let boundStatement: BoundStatement
    
    init(forStatement statement: PreparedStatement) {
        self.boundStatement = BoundStatement(forStatement: statement)
    }
    
    /// Binds `NULL` to the next parameter
    public func bindNull() throws {
        guard boundStatement.boundParameters < boundStatement.statement.parameters.count else {
            throw MySQLError(.tooManyParametersBound)
        }
        
        let bitmapStart = 10
        let byte = boundStatement.boundParameters / 8
        let bit = boundStatement.boundParameters % 8
        
        let bitEncoded: UInt8 = 0b00000001 << (7 - numericCast(bit))
        
        boundStatement.header[bitmapStart + byte] |= bitEncoded
        
        boundStatement.boundParameters += 1
    }
    
    func bind(_ type: Field.FieldType, unsigned: Bool, data: [UInt8]) throws {
        guard boundStatement.boundParameters < boundStatement.statement.parameters.count else {
            throw MySQLError(.tooManyParametersBound)
        }
        
        boundStatement.header.append(type.rawValue)
        boundStatement.header.append(unsigned ? 128 : 0)
        
        boundStatement.parameterData.append(contentsOf: data)
        
        boundStatement.boundParameters += 1
    }
}

