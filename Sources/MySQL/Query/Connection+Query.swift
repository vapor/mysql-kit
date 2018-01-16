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
    public func all<D: Decodable>(_ type: D.Type, in query: MySQLQuery) -> Future<[D]> {
        var results = [D]()
        
        return forEach(D.self, in: query) { entity in
            results.append(entity)
        }.map(to: [D].self) {
            return results
        }
    }
    
    public func stream<D, Stream>(_ type: D.Type, in query: MySQLQuery, to stream: Stream) throws
        where D: Decodable, Stream: Async.InputStream, Stream.Input == D
    {
        let rowStream = ConnectingStream<Row>()
        
        rowStream.map(to: D.self) { row in
            let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
            return try D(from: decoder)
            }.output(to: stream)
        
        stateMachine.send(.textQuery(query.queryString, AnyInputStream(rowStream)))
    }
    
    fileprivate func forEachRow(in query: MySQLQuery, _ handler: @escaping ForEachCallback<Row>) -> Future<Void> {
        let promise = Promise<Void>()
        
        let rows = ConnectingStream<Row>()
        
        stateMachine.send(.textQuery(query.queryString, AnyInputStream(rows)))
        
        _ = rows.drain { row, upstream in
            try handler(row)
            upstream.request()
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
    public func forEach<D>(_ type: D.Type, in query: MySQLQuery, _ handler: @escaping ForEachCallback<D>) -> Future<Void>
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
    public func administrativeQuery(_ query: MySQLQuery) -> Future<Void> {
        let promise = Promise<Void>()
        
        let rows = ConnectingStream<Row>()
        
        _ = rows.drain { _, upstream in
            upstream.request()
        }.catch(onError: promise.fail).finally {
            promise.complete()
        }
        
        stateMachine.send(.textQuery(query.queryString, AnyInputStream(rows)))
        
        return promise.future
    }
    
    /// Prepares a query and calls the captured closure with the prepared statement
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/databases/mysql/prepared-statements/)
    public func withPreparation<T>(statement: MySQLQuery, run closure: @escaping ((PreparedStatement) throws -> Future<T>)) -> Future<T> {
        let promise = Promise<T>()
        
        stateMachine.send(
            .prepare(statement.queryString, { statement in
                    do {
                        try closure(statement).chain(to: promise)
                    } catch {
                        promise.fail(error)
                    }
                }
            )
        )
        
        return promise.future
    }
}
