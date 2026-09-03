import Foundation

/// Options for ``GraphQLClient``.
public struct Configuration: @unchecked Sendable {
    public var endpoint: URL
    public var session: URLSession
    public var encoder: JSONEncoder
    public var decoder: JSONDecoder
    public var defaultHeaders: [String: String]
    public var timeoutInterval: TimeInterval

    public init(
        endpoint: URL,
        session: URLSession = .shared,
        encoder: JSONEncoder = Configuration.makeEncoder(),
        decoder: JSONDecoder = Configuration.makeDecoder(),
        defaultHeaders: [String: String] = [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ],
        timeoutInterval: TimeInterval = 30
    ) {
        self.endpoint = endpoint
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
        self.defaultHeaders = defaultHeaders
        self.timeoutInterval = timeoutInterval
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
