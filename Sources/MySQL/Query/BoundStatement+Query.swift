import Async

extension BoundStatement {
    /// A simple callback closure
    public typealias ForEachCallback<T> = (T) throws -> ()
    
    /// Executes the bound statement and returns all decoded results in a future array
    public func all<D: Decodable>(_ type: D.Type) -> Future<[D]> {
        var results = [D]()
        return self.forEach(D.self) { res in
            results.append(res)
        }.map(to: [D].self) {
            return results
        }
    }
    
    public func stream<D, Stream>(_ type: D.Type, to stream: Stream) throws
        where D: Decodable, Stream: Async.InputStream, Stream.Input == D
    {
        let rowStream = ConnectingStream<Row>()
        
        rowStream.map(to: D.self) { row in
            let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
            return try D(from: decoder)
        }.output(to: stream)
        
        try self.execute(into: AnyInputStream(rowStream))
    }
    
    fileprivate func forEachRow(_ handler: @escaping ForEachCallback<Row>) -> Future<Void> {
        let rows = ConnectingStream<Row>()
        let promise = Promise<Void>()
        
        _ = rows.drain { row in
            try handler(row)
        }.catch(onError: promise.fail).finally {
            promise.complete()
        }
        
        do {
            try self.execute(into: AnyInputStream(rows))
        } catch {
            return Future(error: error)
        }
        
        return promise.future
    }
    
    public func execute() throws -> Future<Void> {
        return self.forEachRow { _ in }
    }
    
    /// Loops over all rows resulting from the query
    ///
    /// - parameter type: Deserializes all rows to the provided `Decodable` `D`
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each deserialized result of type `D`
    /// - throws: Network error
    /// - returns: A future that will be completed when all results have been processed by the handler
    @discardableResult
    public func forEach<D>(_ type: D.Type, _ handler: @escaping ForEachCallback<D>) -> Future<Void>
        where D: Decodable
    {
        return forEachRow { row in
            let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
            let d = try D(from: decoder)
            
            try handler(d)
        }
    }
    
}
