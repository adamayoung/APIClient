// The MIT License (MIT)
//
// Copyright (c) 2021 Alexander Grebenyuk (github.com/kean).

@testable import APIClient
import Mocker
import XCTest

final class APIClientTests: XCTestCase {

    var client: APIClient!

    override func setUp() {
        super.setUp()

        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self]

        client = APIClient(host: "api.github.com", configuration: configuration)
    }

    override func tearDown() {
        client = nil

        super.tearDown()
    }

    func testDefiningRequestInline() async throws {
        let url = URL(string: "https://api.github.com/user")!
        Mock(url: url, dataType: .json, statusCode: 200, data: [
            .get: json(named: "user")
        ]).register()

        let user: User = try await client.value(for: .get("/user"))

        XCTAssertEqual(user.login, "adamayoung")
    }

    func testCancellingTheRequest() async throws {
        let url = URL(string: "https://api.github.com/users/kean")!
        var mock = Mock(url: url, dataType: .json, statusCode: 200, data: [
            .get: json(named: "user")
        ])
        mock.delay = DispatchTimeInterval.seconds(60)
        mock.register()

        let task = Task {
            try await client.send(.get("/users/kean"))
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(100)) {
            task.cancel()
        }

        do {
            _ = try await task.value
        } catch {
            XCTAssertTrue(error is URLError)
            XCTAssertEqual((error as? URLError)?.code, .cancelled)
        }
    }

    func testDecodingWithDecodableResponse() async throws {
        let url = URL(string: "https://api.github.com/user")!
        Mock(url: url, dataType: .json, statusCode: 200, data: [
            .get: json(named: "user")
        ]).register()

        let user: User = try await client.value(for: .get("/user"))

        XCTAssertEqual(user.login, "adamayoung")
    }

    func testDecodingWithVoidResponse() async throws {
        #if os(watchOS)
        throw XCTSkip("Mocker URLProtocol isn't being called for POST requests on watchOS")
        #endif

        let url = URL(string: "https://api.github.com/user")!
        Mock(url: url, dataType: .json, statusCode: 200, data: [
            .post: json(named: "user")
        ]).register()

        let request = Request<Void>.post("/user", body: ["login": "kean"])
        try await client.send(request)
    }

    func testResponse() async throws {
        let url = URL(string: "https://api.github.com/user")!
        Mock(url: url, dataType: .json, statusCode: 200, data: [
            .get: json(named: "user")
        ]).register()

        let response = try await client.send(Resources.user.get)

        XCTAssertEqual(response.value.login, "adamayoung")
        XCTAssertEqual(response.data.count, 1432)
        XCTAssertEqual(response.request.url, url)
        XCTAssertEqual(response.statusCode, 200)
    }

    // MARK: - Authorization

    func testAuthorizationHeaderIsPassed() async throws {
        let delegate = MockAuthorizatingDelegate()

        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self]

        client = APIClient(host: "api.github.com", configuration: configuration, delegate: delegate)

        let url = URL(string: "https://api.github.com/user")!
        var mock = Mock(url: url, dataType: .json, statusCode: 401, data: [
            .get: "Unauthorized".data(using: .utf8)!
        ])

        mock.onRequest = { request, _ in
            XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer: expired-token")

            delegate.token = "valid-token"
            var mock = Mock(url: url, dataType: .json, statusCode: 200, data: [
                .get: json(named: "user")
            ])
            mock.onRequest = { request, _ in
                XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer: valid-token")
            }
            mock.register()
        }
        mock.register()

        let user: User = try await client.value(for: .get("/user"))

        XCTAssertEqual(user.login, "adamayoung")
    }
}
