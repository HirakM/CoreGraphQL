import Foundation
import Testing
@testable import CoreGraphQL

struct User: Decodable, Equatable {
    var id: String
    var name: String
}

struct UserData: Decodable, Equatable {
    var user: User
}

struct UserVariables: Encodable {
    var id: String
}

@Suite(.serialized)
struct GraphQLClientTests {
    func makeClient() -> GraphQLClient {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        sessionConfig.timeoutIntervalForRequest = 2
        return GraphQLClient(
            configuration: Configuration(
                endpoint: URL(string: "https://api.example.com/graphql")!,
                session: URLSession(configuration: sessionConfig)
            )
        )
    }

    @Test
    func queryDecodesData() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.handler = { _ in
            let data = Data(#"{"data":{"user":{"id":"1","name":"Hirak"}}}"#.utf8)
            return (200, data, [:])
        }

        let client = makeClient()
        let result: UserData = try await client.query(
            "query User($id: ID!) { user(id: $id) { id name } }",
            variables: UserVariables(id: "1")
        )
        #expect(result.user == User(id: "1", name: "Hirak"))
        #expect(MockURLProtocol.requests.first?.httpMethod == "POST")
        #expect(MockURLProtocol.requests.first?.url?.absoluteString == "https://api.example.com/graphql")
    }

    @Test
    func requestBodyIncludesQueryAndVariables() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.handler = { _ in
            (200, Data(#"{"data":{"user":{"id":"1","name":"Hirak"}}}"#.utf8), [:])
        }

        let client = makeClient()
        let _: UserData = try await client.query(
            "query User($id: ID!) { user(id: $id) { id name } }",
            operationName: "User",
            variables: UserVariables(id: "1")
        )

        let json = try JSONSerialization.jsonObject(
            with: MockURLProtocol.requests.first?.httpBody ?? Data()
        ) as? [String: Any]
        #expect(json?["operationName"] as? String == "User")
        #expect((json?["query"] as? String)?.contains("user(id: $id)") == true)
        let variables = json?["variables"] as? [String: Any]
        #expect(variables?["id"] as? String == "1")
    }

    @Test
    func attachesCustomHeader() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.handler = { _ in
            (200, Data(#"{"data":{"user":{"id":"1","name":"Hirak"}}}"#.utf8), [:])
        }

        let client = makeClient()
        let _: UserData = try await client.query(
            "{ user { id name } }",
            headers: ["Authorization": "Bearer secret"]
        )
        #expect(MockURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test
    func graphQLErrorsThrow() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.handler = { _ in
            let data = Data(#"{"errors":[{"message":"User not found","path":["user"]}]}"#.utf8)
            return (200, data, [:])
        }

        let client = makeClient()
        await #expect(throws: GraphQLError.operation([
            GraphQLServerError(message: "User not found", locations: nil, path: [.field("user")])
        ])) {
            let _: UserData = try await client.query("{ user { id name } }")
        }
    }

    @Test
    func maps401ToUnauthorized() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.handler = { _ in (401, Data(), [:]) }

        let client = makeClient()
        await #expect(throws: GraphQLError.unauthorized) {
            let _: UserData = try await client.query("{ user { id name } }")
        }
    }

    @Test
    func httpErrorIncludesStatus() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.handler = { _ in (500, Data("fail".utf8), [:]) }

        let client = makeClient()
        await #expect(throws: GraphQLError.http(statusCode: 500, body: Data("fail".utf8))) {
            let _: UserData = try await client.query("{ user { id name } }")
        }
    }

    @Test
    func mutatePostsTheDocument() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.handler = { _ in
            (200, Data(#"{"data":{"user":{"id":"2","name":"Hirak"}}}"#.utf8), [:])
        }

        let client = makeClient()
        let result: UserData = try await client.mutate(
            "mutation { updateUser { id name } }"
        )
        #expect(result.user.id == "2")
        #expect(MockURLProtocol.requests.first?.httpMethod == "POST")
    }
}
