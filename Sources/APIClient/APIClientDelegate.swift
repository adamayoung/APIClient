import Foundation

// swiftlint:disable class_delegate_protocol
public protocol APIClientDelegate {

    func client(_ client: APIClient, willSendRequest request: inout URLRequest)

    func shouldClientRetry(_ client: APIClient, withError error: Error) async -> Bool

    func client(_ client: APIClient, didReceiveInvalidResponse response: HTTPURLResponse, data: Data) -> Error

}
// swiftlint:enable class_delegate_protocol

public extension APIClientDelegate {

    func client(_ client: APIClient, willSendRequest request: inout URLRequest) { }

    func shouldClientRetry(_ client: APIClient, withError error: Error) async -> Bool {
        false
    }

    func client(_ client: APIClient, didReceiveInvalidResponse response: HTTPURLResponse, data: Data) -> Error {
        APIError.unacceptableStatusCode(response.statusCode)
    }

}
