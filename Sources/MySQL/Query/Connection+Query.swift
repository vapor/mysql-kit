import Async
import Foundation

extension MySQLConnection {
    /// A function that shoots a raw query without expecting a real answer
    @discardableResult
    public func administrativeQuery(_ query: MySQLQuery) -> Future<Void> {
        let promise = Promise<Void>()
        
        let rows = ConnectingStream<Row>()
        
        stateMachine.send(.textQuery(query.queryString, AnyInputStream(rows)))
        
        _ = rows.drain { _, upstream in
            upstream.request()
        }.catch(onError: promise.fail).finally {
            promise.complete()
        }
        
        return promise.future
    }
}
