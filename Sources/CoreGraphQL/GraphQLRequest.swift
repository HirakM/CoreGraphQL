import Foundation

struct GraphQLRequestBody<Variables: Encodable>: Encodable {
    var query: String
    var operationName: String?
    var variables: Variables?

    enum CodingKeys: String, CodingKey {
        case query
        case operationName
        case variables
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
        try container.encodeIfPresent(operationName, forKey: .operationName)
        try container.encodeIfPresent(variables, forKey: .variables)
    }
}

struct GraphQLEnvelope<Data: Decodable>: Decodable {
    var data: Data?
    var errors: [GraphQLServerError]?
}
