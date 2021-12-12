import Foundation

public struct Response<T> {

    public let value: T
    /// Original response data.
    public let data: Data
    /// Original request.
    public let request: URLRequest
    public let response: HTTPURLResponse
    public let statusCode: Int

    func map<U>(_ closure: (T) -> U) -> Response<U> {
        Response<U>(value: closure(value), data: data, request: request, response: response, statusCode: statusCode)
    }

}
