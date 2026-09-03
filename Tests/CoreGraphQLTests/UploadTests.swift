import Foundation
import Testing
@testable import CoreGraphQL

extension GraphQLClientTests {
    @Test
    func uploadSendsMultipartBody() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.handler = { _ in
            (200, Data(#"{"data":{"user":{"id":"9","name":"Hirak"}}}"#.utf8), [:])
        }

        let file = GraphQLFile(data: Data("hello".utf8), filename: "note.txt", mimeType: "text/plain")
        let client = makeClient()
        let result: UserData = try await client.upload(
            "mutation ($file: Upload!) { upload(file: $file) { id name } }",
            variables: ["title": "doc"],
            files: ["file": file]
        )
        #expect(result.user.id == "9")

        let request = try #require(MockURLProtocol.requests.first)
        let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? ""
        #expect(contentType.contains("multipart/form-data"))
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        #expect(body.contains("name=\"operations\""))
        #expect(body.contains("name=\"map\""))
        #expect(body.contains("filename=\"note.txt\""))
        #expect(body.contains("\"file\":null"))
        #expect(body.contains("variables.file"))
        #expect(body.contains("hello"))
    }
}
