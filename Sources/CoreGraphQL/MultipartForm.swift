import Foundation

struct MultipartForm {
    let boundary: String
    private var body = Data()

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    init(boundary: String = "CoreGraphQL-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    mutating func addJSONField(name: String, data: Data) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n")
        append("Content-Type: application/json\r\n\r\n")
        body.append(data)
        append("\r\n")
    }

    mutating func addFileField(name: String, file: GraphQLFile) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(file.filename)\"\r\n")
        append("Content-Type: \(file.mimeType)\r\n\r\n")
        body.append(file.data)
        append("\r\n")
    }

    mutating func finish() -> Data {
        append("--\(boundary)--\r\n")
        return body
    }

    private mutating func append(_ string: String) {
        body.append(Data(string.utf8))
    }
}

enum JSONPath {
    static func setNull(_ object: inout [String: Any], path: String) {
        set(value: NSNull(), on: &object, components: path.split(separator: ".").map(String.init))
    }

    private static func set(value: Any, on object: inout [String: Any], components: [String]) {
        guard let first = components.first else { return }
        if components.count == 1 {
            object[first] = value
            return
        }

        let rest = Array(components.dropFirst())
        if let index = Int(rest[0]) {
            var array = object[first] as? [Any] ?? []
            while array.count <= index {
                array.append(NSNull())
            }
            if rest.count == 1 {
                array[index] = value
            } else if var nested = array[index] as? [String: Any] {
                set(value: value, on: &nested, components: Array(rest.dropFirst()))
                array[index] = nested
            } else {
                var nested: [String: Any] = [:]
                set(value: value, on: &nested, components: Array(rest.dropFirst()))
                array[index] = nested
            }
            object[first] = array
        } else {
            var nested = object[first] as? [String: Any] ?? [:]
            set(value: value, on: &nested, components: rest)
            object[first] = nested
        }
    }
}
