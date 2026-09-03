import Foundation

public enum CodegenCLI {
    public static func run(arguments: [String]) throws {
        let options = try Options.parse(arguments)
        let schemaURL = URL(fileURLWithPath: options.schema)
        let outputURL = URL(fileURLWithPath: options.output)
        let data = try Data(contentsOf: schemaURL)
        let schema: GraphQLSchemaDocument
        if schemaURL.pathExtension.lowercased() == "json" {
            schema = try IntrospectionLoader.load(from: data)
        } else {
            guard let source = String(data: data, encoding: .utf8) else {
                throw CodegenError.io("Schema file is not valid UTF-8.")
            }
            schema = try SDLParser.parse(source)
        }
        let swift = SwiftGenerator(access: options.access).generate(schema)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try swift.write(to: outputURL, atomically: true, encoding: .utf8)
    }
}

private struct Options {
    var schema: String
    var output: String
    var access: String

    static func parse(_ arguments: [String]) throws -> Options {
        var schema: String?
        var output: String?
        var access = "public"
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--schema":
                schema = try value(after: argument, in: arguments, index: &index)
            case "--output":
                output = try value(after: argument, in: arguments, index: &index)
            case "--access":
                access = try value(after: argument, in: arguments, index: &index)
            case "--help", "-h":
                throw CodegenError.missingArgument(Self.usage)
            default:
                throw CodegenError.missingArgument("Unknown argument \(argument).\n\(Self.usage)")
            }
            index += 1
        }
        guard let schema, let output else {
            throw CodegenError.missingArgument(Self.usage)
        }
        guard access == "public" || access == "internal" else {
            throw CodegenError.missingArgument("--access must be public or internal.")
        }
        return Options(schema: schema, output: output, access: access)
    }

    private static func value(after flag: String, in arguments: [String], index: inout Int) throws -> String {
        index += 1
        guard index < arguments.count else {
            throw CodegenError.missingArgument("\(flag) requires a value.\n\(usage)")
        }
        return arguments[index]
    }

    static let usage = """
        Usage: coregraphql-codegen --schema <schema.graphql|introspection.json> --output <Schema.swift> [--access public|internal]
        """
}
