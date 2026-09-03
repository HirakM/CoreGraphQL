import Foundation

/// An async GraphQL client on top of `URLSession`.
///
/// POST-only. No codegen, subscriptions, or file uploads.
///
/// ```swift
/// let client = GraphQLClient(endpoint: URL(string: "https://api.example.com/graphql")!)
///
/// struct UserData: Decodable {
///     var user: User
/// }
/// struct User: Decodable {
///     var id: String
///     var name: String
/// }
///
/// let data: UserData = try await client.query(
///     """
///     query User($id: ID!) {
///       user(id: $id) { id name }
///     }
///     """,
///     variables: ["id": "1"]
/// )
/// ```
public struct GraphQLClient: @unchecked Sendable {
    public let configuration: Configuration

    public var encoder: JSONEncoder { configuration.encoder }
    public var decoder: JSONDecoder { configuration.decoder }

    public init(endpoint: URL, session: URLSession = .shared) {
        self.init(configuration: Configuration(endpoint: endpoint, session: session))
    }

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func query<Response: Decodable>(
        _ document: String,
        operationName: String? = nil,
        headers: [String: String] = [:]
    ) async throws -> Response {
        try await execute(
            document,
            operationName: operationName,
            variables: Optional<EmptyVariables>.none,
            headers: headers
        )
    }

    public func query<Variables: Encodable, Response: Decodable>(
        _ document: String,
        operationName: String? = nil,
        variables: Variables,
        headers: [String: String] = [:]
    ) async throws -> Response {
        try await execute(
            document,
            operationName: operationName,
            variables: variables,
            headers: headers
        )
    }

    public func mutate<Response: Decodable>(
        _ document: String,
        operationName: String? = nil,
        headers: [String: String] = [:]
    ) async throws -> Response {
        try await query(document, operationName: operationName, headers: headers)
    }

    public func mutate<Variables: Encodable, Response: Decodable>(
        _ document: String,
        operationName: String? = nil,
        variables: Variables,
        headers: [String: String] = [:]
    ) async throws -> Response {
        try await query(
            document,
            operationName: operationName,
            variables: variables,
            headers: headers
        )
    }

    private func execute<Variables: Encodable, Response: Decodable>(
        _ document: String,
        operationName: String?,
        variables: Variables?,
        headers: [String: String]
    ) async throws -> Response {
        let body = GraphQLRequestBody(
            query: document,
            operationName: operationName,
            variables: variables
        )

        let payload: Data
        do {
            payload = try encoder.encode(body)
        } catch {
            throw GraphQLError.encodingFailed
        }

        var request = URLRequest(url: configuration.endpoint, timeoutInterval: configuration.timeoutInterval)
        request.httpMethod = "POST"
        request.httpBody = payload

        var merged = configuration.defaultHeaders
        headers.forEach { merged[$0.key] = $0.value }
        merged.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await configuration.session.data(for: request)
        } catch let urlError as URLError {
            if urlError.code == .cancelled { throw GraphQLError.cancelled }
            throw GraphQLError.transport(urlError.localizedDescription)
        } catch is CancellationError {
            throw GraphQLError.cancelled
        } catch {
            throw GraphQLError.transport(error.localizedDescription)
        }

        guard let http = urlResponse as? HTTPURLResponse else {
            throw GraphQLError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { throw GraphQLError.unauthorized }
            throw GraphQLError.http(statusCode: http.statusCode, body: data)
        }

        let envelope: GraphQLEnvelope<Response>
        do {
            envelope = try decoder.decode(GraphQLEnvelope<Response>.self, from: data)
        } catch {
            throw GraphQLError.decodingFailed(error.localizedDescription)
        }

        if let errors = envelope.errors, !errors.isEmpty {
            throw GraphQLError.operation(errors)
        }

        guard let value = envelope.data else {
            throw GraphQLError.decodingFailed("GraphQL response had no data.")
        }

        return value
    }
}

private struct EmptyVariables: Encodable {}
