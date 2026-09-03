import Foundation
import Testing
@testable import CoreGraphQLCodegen

@Suite
struct CodegenTests {
    @Test
    func parsesSDLAndGeneratesSwift() throws {
        let sdl = """
            scalar Date

            enum Role {
              ADMIN
              USER
            }

            input UserInput {
              name: String!
              role: Role
            }

            type User {
              id: ID!
              name: String
              tags: [String!]!
            }

            union SearchResult = User | Role
            """

        let schema = try SDLParser.parse(sdl)
        #expect(schema.scalars.contains("Date"))
        #expect(schema.enums.contains(where: { $0.name == "Role" && $0.values == ["ADMIN", "USER"] }))
        #expect(schema.inputs.contains(where: { $0.name == "UserInput" }))
        #expect(schema.objects.contains(where: { $0.name == "User" }))

        let swift = SwiftGenerator().generate(schema)
        #expect(swift.contains("public typealias Date = String"))
        #expect(swift.contains("public enum Role: String, Codable, Sendable"))
        #expect(swift.contains("case admin = \"ADMIN\""))
        #expect(swift.contains("public struct User: Decodable, Sendable"))
        #expect(swift.contains("public var id: String"))
        #expect(swift.contains("public var name: String?"))
        #expect(swift.contains("public var tags: [String]"))
        #expect(swift.contains("public struct UserInput: Codable, Sendable"))
        #expect(swift.contains("import CoreGraphQL"))
    }

    @Test
    func loadsIntrospectionJSON() throws {
        let json = """
            {
              "__schema": {
                "types": [
                  {
                    "kind": "OBJECT",
                    "name": "User",
                    "fields": [
                      {
                        "name": "id",
                        "type": { "kind": "NON_NULL", "name": null, "ofType": { "kind": "SCALAR", "name": "ID", "ofType": null } }
                      }
                    ]
                  },
                  { "kind": "SCALAR", "name": "ID" }
                ]
              }
            }
            """
        let schema = try IntrospectionLoader.load(from: Data(json.utf8))
        #expect(schema.objects.contains(where: { $0.name == "User" }))
        let swift = SwiftGenerator().generate(schema)
        #expect(swift.contains("public var id: String"))
    }
}
