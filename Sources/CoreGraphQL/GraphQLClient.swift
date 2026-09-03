import Foundation

/// An async GraphQL client on top of `URLSession`.
///
/// POST-only. No subscriptions.
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

    /// Mutation with file uploads ([multipart spec](https://github.com/jaydenseric/graphql-multipart-request-spec)).
    ///
    /// `files` keys are variable paths (`"file"` or `"files.0"`). Those paths are
    /// set to JSON `null` in `operations` and mapped to the file parts.
    public func upload<Variables: Encodable, Response: Decodable>(
        _ document: String,
        operationName: String? = nil,
        variables: Variables,
        files: [String: GraphQLFile],
        headers: [String: String] = [:]
    ) async throws -> Response {
        try await execute(
            document,
            operationName: operationName,
            variables: variables,
            files: files,
            headers: headers
        )
    }

    public func upload<Response: Decodable>(
        _ document: String,
        operationName: String? = nil,
        files: [String: GraphQLFile],
        headers: [String: String] = [:]
    ) async throws -> Response {
        try await upload(
            document,
            operationName: operationName,
            variables: EmptyVariables(),
            files: files,
            headers: headers
        )
    }

    private func execute<Variables: Encodable, Response: Decodable>(
        _ document: String,
        operationName: String?,
        variables: Variables?,
        files: [String: GraphQLFile] = [:],
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

        if files.isEmpty {
            request.httpBody = payload
            applyHeaders(headers, contentType: "application/json", to: &request)
        } else {
            let multipart: (Data, String)
            do {
                multipart = try makeMultipartBody(operationsJSON: payload, files: files)
            } catch {
                throw GraphQLError.encodingFailed
            }
            request.httpBody = multipart.0
            applyHeaders(headers, contentType: multipart.1, to: &request)
        }

        return try await send(request)
    }

    private func applyHeaders(_ headers: [String: String], contentType: String, to request: inout URLRequest) {
        var merged = configuration.defaultHeaders
        headers.forEach { merged[$0.key] = $0.value }
        merged["Content-Type"] = contentType
        merged.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
    }

    private func makeMultipartBody(
        operationsJSON: Data,
        files: [String: GraphQLFile]
    ) throws -> (Data, String) {
        guard var operations = try JSONSerialization.jsonObject(with: operationsJSON) as? [String: Any] else {
            throw GraphQLError.encodingFailed
        }
        var variables = operations["variables"] as? [String: Any] ?? [:]

        let ordered = files.sorted(by: { $0.key < $1.key })
        var map: [String: [String]] = [:]
        for (index, (path, _)) in ordered.enumerated() {
            JSONPath.setNull(&variables, path: path)
            map["\(index)"] = ["variables.\(path)"]
        }
        operations["variables"] = variables

        let operationsData = try JSONSerialization.data(withJSONObject: operations, options: [.sortedKeys])
        let mapData = try JSONSerialization.data(withJSONObject: map, options: [.sortedKeys])

        var form = MultipartForm()
        form.addJSONField(name: "operations", data: operationsData)
        form.addJSONField(name: "map", data: mapData)
        for (index, (_, file)) in ordered.enumerated() {
            form.addFileField(name: "\(index)", file: file)
        }
        return (form.finish(), form.contentType)
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
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
