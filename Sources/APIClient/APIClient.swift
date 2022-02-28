import Foundation

/// An API Client.
public actor APIClient {

    let conf: Configuration
    private let session: URLSession
    private let serializer: Serializer
    // swiftlint:disable weak_delegate
    private let clientDelegate: APIClientDelegate
    // swiftlint:enable weak_delegate

    /// Configuration for an API Client.
    public struct Configuration {

        /// Host.
        public let host: String
        /// Base Path.
        public let basePath: String?
        /// Port.
        public let port: Int?
        /// If `true`, uses `http` instead of `https`.
        public let isInsecure: Bool
        /// Sessing configuration. By default, uses `URLSessionConfiguration.default`.
        public let sessionConfiguration: URLSessionConfiguration
        /// By default, uses decoder with `.iso8601` date decoding strategy.
        public let decoder: JSONDecoder?
        /// By default, uses encoder with `.iso8601` date encoding strategy.
        public let encoder: JSONEncoder?
        // swiftlint:disable weak_delegate
        public let clientDelegate: APIClientDelegate?
        // swiftlint:enable weak_delegate

        public init(host: String, basePath: String? = nil, port: Int? = nil, isInsecure: Bool = false,
                    sessionConfiguration: URLSessionConfiguration = .default, decoder: JSONDecoder? = nil,
                    encoder: JSONEncoder? = nil, clientDelegate: APIClientDelegate? = nil) {
            self.host = host
            self.basePath = basePath
            self.port = port
            self.isInsecure = isInsecure
            self.sessionConfiguration = sessionConfiguration
            self.decoder = decoder
            self.encoder = encoder
            self.clientDelegate = clientDelegate
        }

    }

    /// Initializes the client with the given parameters.
    ///
    /// - parameters:
    ///    - host: A host to be used for requests with relative paths.
    ///    - configuration: By default, `URLSessionConfiguration.default`.
    ///    - delegate: A delegate to customize various aspects of the client.
    public convenience init(host: String, configuration: URLSessionConfiguration = .default,
                            delegate: APIClientDelegate? = nil) {
        let config = Configuration(host: host, sessionConfiguration: configuration, clientDelegate: delegate)
        self.init(configuration: config)
    }

    /// Initializes the client with the given configuration.
    public init(configuration: Configuration) {
        self.conf = configuration
        self.session = URLSession(configuration: configuration.sessionConfiguration)
        self.clientDelegate = configuration.clientDelegate ?? DefaultAPIClientDelegate()
        self.serializer = Serializer(decoder: configuration.decoder, encoder: configuration.encoder)
    }

    /// Returns a decoded response value for the given request.
    public func value<T: Decodable>(for request: Request<T>) async throws -> T {
        try await send(request).value
    }

    /// Sends the given request and returns a response with a decoded response value.
    public func send<T: Decodable>(_ request: Request<T>) async throws -> Response<T> {
        try await send(request, serializer.decode)
    }

    /// Sends the given request.
    @discardableResult
    public func send(_ request: Request<Void>) async throws -> Response<Void> {
        try await send(request) { _ in () }
    }

    /// Returns response data for the given request.
    public func data<T>(for request: Request<T>) async throws -> Response<Data> {
        let request = try await makeRequest(for: request)
        return try await send(request)
    }

}

extension APIClient {

    private func send<T>(_ request: Request<T>,
                         _ decode: @escaping (Data) async throws -> T) async throws -> Response<T> {
        let response = try await data(for: request)
        let value = try await decode(response.value)
        return response.map { _ in value }
    }

    private func send(_ request: URLRequest) async throws -> Response<Data> {
        do {
            return try await actuallySend(request)
        } catch {
            guard await clientDelegate.shouldClientRetry(self, withError: error) else {
                throw error
            }

            return try await actuallySend(request)
        }
    }

    private func actuallySend(_ request: URLRequest) async throws -> Response<Data> {
        var request = request
        clientDelegate.client(self, willSendRequest: &request)

        let (data, response) =
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
            session.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (data!, response!))
            }.resume()
        }

//        let (data, response) = try await session.data(for: request, delegate: nil)
        try validate(response: response, data: data)
        let httpResponse = (response as? HTTPURLResponse) ?? HTTPURLResponse()
        return Response(value: data, data: data, request: request, response: httpResponse,
                        statusCode: httpResponse.statusCode)
    }

    private func makeRequest<T>(for request: Request<T>) async throws -> URLRequest {
        let url = try makeURL(path: request.path, query: request.query)
        return try await makeRequest(url: url, method: request.method, body: request.body)
    }

    private func makeURL(path: String, query: [String: CustomStringConvertible?]?) throws -> URL {
        var path = path
        if let basePath = conf.basePath {
            path = "\(basePath)\(path)"
        }

        guard
            let url = URL(string: path),
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            throw URLError(.badURL)
        }

        if path.starts(with: "/") {
            components.scheme = conf.isInsecure ? "http" : "https"
            components.host = conf.host
            if let port = conf.port {
                components.port = port
            }
        }

        if let query = query {
            components.queryItems = query.compactMap { key, value in
                guard let value = value?.description else {
                    return nil
                }

                return URLQueryItem(name: key, value: value)
            }
        }

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        return url
    }

    private func makeRequest(url: URL, method: HTTPMethod, body: AnyEncodable?) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let body = body {
            request.httpBody = try await serializer.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            throw clientDelegate.client(self, didReceiveInvalidResponse: httpResponse, data: data)
        }
    }

}
