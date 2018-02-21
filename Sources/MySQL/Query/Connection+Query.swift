import Async

extension MySQLConnection {
    /// A simple callback closure
    public typealias ForEachCallback<T> = (T) throws -> ()
    
    /// Collects all decoded results and returs them in the future
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/mysql/basics/#futures)
    ///
    /// - parameter query: The query to be executed to receive results from
    /// - returns: A future containing all results
    public func all<D: Decodable>(_ type: D.Type, in query: String) -> Future<[D]> {
        var results = [D]()
        
        return forEach(D.self, in: query) { entity in
            results.append(entity)
        }.map(to: [D].self) {
            return results
        }
    }
    
    public func stream<D, Stream>(_ type: D.Type, in query: String, to stream: Stream) throws
        where D: Decodable, Stream: Async.InputStream, Stream.Input == D
    {
        let rowStream = PushStream<Row>()
        
        rowStream.map(to: D.self) { row in
            let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
            return try D(from: decoder)
        }.output(to: stream)
        
        
        stateMachine.execute(TextQuery(query: query, stream: rowStream, context: self.stateMachine))
    }
    
    fileprivate func forEachRow(in query: String, _ handler: @escaping ForEachCallback<Row>) -> Future<Void> {
        let promise = Promise<Void>()
        
        let rows = PushStream<Row>()
        
        stateMachine.execute(TextQuery(query: query, stream: rows, context: self.stateMachine))
        
        _ = rows.drain { row in
            try handler(row)
        }.catch(onError: promise.fail).finally {
            promise.complete()
        }
        
        return promise.future
    }
    
    /// Loops over all rows resulting from the query
    ///
    /// - parameter type: Deserializes all rows to the provided `Decodable` `D`
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each deserialized result of type `D`
    /// - throws: Network error
    /// - returns: A future that will be completed when all results have been processed by the handler
    @discardableResult
    public func forEach<D>(_ type: D.Type, in query: String, _ handler: @escaping ForEachCallback<D>) -> Future<Void>
        where D: Decodable
    {
        return forEachRow(in: query) { row in
            let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
            let d = try D(from: decoder)
            
            try handler(d)
        }
    }
    
    /// A function that shoots a raw query without expecting a real answer
    @discardableResult
    public func administrativeQuery(_ query: String) -> Future<Void> {
        let promise = Promise<Void>()
        
        let rows = PushStream<Row>()
        
        _ = rows.drain { _ in }.catch(onError: promise.fail).finally {
            promise.complete()
        }
        
        stateMachine.execute(TextQuery(query: query, stream: rows, context: self.stateMachine))
        
        return promise.future
    }
    
    /// Prepares a query and calls the captured closure with the prepared statement
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/databases/mysql/prepared-statements/)
    public func withPreparation<T>(statement: String, run closure: @escaping ((PreparedStatement) throws -> Future<T>)) -> Future<T> {
        let promise = Promise<T>()
        
        let task = PrepareQuery(query: statement, context: self.stateMachine) { statement, sqlError in
            do {
                if let statement = statement {
                    try closure(statement).chain(to: promise)
                } else if let sqlError = sqlError {
                    throw sqlError
                } else {
                    throw MySQLError(.invalidResponse)
                }
            } catch {
                promise.fail(error)
            }
        }
        
        stateMachine.execute(task)
        
        return promise.future
    }
}
