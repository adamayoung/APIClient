import Foundation

public struct Request<Response> {

    public let id = UUID()
    public let method: HTTPMethod
    public let path: String
    public let query: [String: String?]?
    let body: AnyEncodable?

    init(method: HTTPMethod, path: String, query: [String: String?]? = nil, body: AnyEncodable? = nil) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
    }

    public static func get(_ path: String, query: [String: String?]? = nil) -> Request {
        Request(method: .get, path: path, query: query)
    }

    public static func post<U: Encodable>(_ path: String, body: U) -> Request {
        Request(method: .post, path: path, body: AnyEncodable(body))
    }

    public static func patch<U: Encodable>(_ path: String, body: U) -> Request {
        Request(method: .patch, path: path, body: AnyEncodable(body))
    }

    public static func put<U: Encodable>(_ path: String, body: U) -> Request {
        Request(method: .put, path: path, body: AnyEncodable(body))
    }

    public static func delete(_ path: String, query: [String: String?]? = nil) -> Request {
        Request(method: .delete, path: path, query: query)
    }

    public static func options(_ path: String, query: [String: String?]? = nil) -> Request {
        Request(method: .options, path: path, query: query)
    }

    public static func head(_ path: String, query: [String: String?]? = nil) -> Request {
        Request(method: .head, path: path, query: query)
    }

    public static func trace(_ path: String, query: [String: String?]? = nil) -> Request {
        Request(method: .trace, path: path, query: query)
    }

}
