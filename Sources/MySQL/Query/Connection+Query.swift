import Async
import Foundation

extension MySQLConnection {
    /// A function that shoots a raw query without expecting a real answer
    @discardableResult
    public func administrativeQuery(_ query: MySQLQuery) -> Future<Void> {
        let promise = Promise<Void>()
        let stream = DrainStream<Row>().catch(onError: promise.fail).finally {
            promise.complete()
        }
        
        stateMachine.send(.textQuery(query.queryString, AnyInputStream(stream)))
        
        return promise.future
    }
}
