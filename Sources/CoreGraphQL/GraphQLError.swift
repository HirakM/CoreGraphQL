import Foundation

/// A field name or list index in a GraphQL error `path`.
public enum GraphQLPathSegment: Sendable, Equatable, Decodable {
    case field(String)
    case index(Int)

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .index(value)
        } else {
            self = .field(try container.decode(String.self))
        }
    }
}

/// One error object from a GraphQL `errors` array.
public struct GraphQLServerError: Decodable, Sendable, Equatable {
    public var message: String
    public var locations: [Location]?
    public var path: [GraphQLPathSegment]?

    public struct Location: Decodable, Sendable, Equatable {
        public var line: Int
        public var column: Int
    }
}

/// Failures thrown by ``GraphQLClient``.
public enum GraphQLError: Error, Equatable, LocalizedError, Sendable {
    case encodingFailed
    case decodingFailed(String)
    case invalidResponse
    case http(statusCode: Int, body: Data)
    case transport(String)
    case unauthorized
    case cancelled
    /// The server returned a GraphQL `errors` array.
    case operation([GraphQLServerError])

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "The GraphQL request could not be encoded."
        case .decodingFailed(let message):
            "The GraphQL response could not be decoded: \(message)"
        case .invalidResponse:
            "The server did not return an HTTP response."
        case .http(let statusCode, _):
            "Request failed with HTTP \(statusCode)."
        case .transport(let message):
            "The request failed in transport: \(message)"
        case .unauthorized:
            "The request was not authorized."
        case .cancelled:
            "The request was cancelled."
        case .operation(let errors):
            errors.map(\.message).joined(separator: "; ")
        }
    }
}
