import Foundation
import PackagePlugin

@main
struct GenerateGraphQLPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        let tool = try context.tool(named: "coregraphql-codegen")
        let process = Process()
        process.executableURL = tool.url
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw PluginError.failed(process.terminationStatus)
        }
    }
}

enum PluginError: Error, CustomStringConvertible {
    case failed(Int32)

    var description: String {
        switch self {
        case .failed(let status):
            "coregraphql-codegen exited with status \(status)."
        }
    }
}
