import Async

extension MySQLConnection {
    /// A simple callback closure
    public typealias Callback<T> = (T) throws -> ()
    
    public func stream<D, Stream>(_ type: D.Type, in query: MySQLQuery, to stream: Stream) throws
        where D: Decodable, Stream: InputStream, Stream.Input == D
    {
        let rowStream = ConnectingStream<Row>()
        
        rowStream.map(to: D.self) { row in
            let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
            return try D(from: decoder)
        }.output(to: stream)
        
        stateMachine.send(.textQuery(query.queryString, AnyInputStream(rowStream)))
    }
    
    fileprivate func forEachRow(in query: MySQLQuery, _ handler: @escaping Callback<Row>) -> Future<Void> {
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
    public func forEach<D>(_ type: D.Type, in query: MySQLQuery, _ handler: @escaping Callback<D>) -> Future<Void>
        where D: Decodable
    {
        return forEachRow(in: query) { row in
            let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
            let d = try D(from: decoder)
            
            try handler(d)
        }
    }
}

