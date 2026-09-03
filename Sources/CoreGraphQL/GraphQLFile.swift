import Foundation

/// A file to send with the [GraphQL multipart request spec](https://github.com/jaydenseric/graphql-multipart-request-spec).
///
/// Encodes as JSON `null` so it can sit in an `Encodable` variables struct;
/// pass the same value in `files:` on ``GraphQLClient/upload(_:operationName:variables:files:headers:)``.
public struct GraphQLFile: Sendable {
    public var data: Data
    public var filename: String
    public var mimeType: String

    public init(data: Data, filename: String, mimeType: String = "application/octet-stream") {
        self.data = data
        self.filename = filename
        self.mimeType = mimeType
    }
}

extension GraphQLFile: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}
