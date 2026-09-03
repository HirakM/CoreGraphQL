import Foundation
import CoreGraphQLCodegen

@main
struct CoreGraphQLCodegenMain {
    static func main() {
        do {
            try CodegenCLI.run(arguments: CommandLine.arguments)
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}
