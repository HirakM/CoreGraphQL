// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoreGraphQL",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "CoreGraphQL", targets: ["CoreGraphQL"]),
        .executable(name: "coregraphql-codegen", targets: ["coregraphql-codegen"]),
        .plugin(name: "GenerateGraphQL", targets: ["GenerateGraphQL"])
    ],
    targets: [
        .target(
            name: "CoreGraphQL",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .target(
            name: "CoreGraphQLCodegen",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .executableTarget(
            name: "coregraphql-codegen",
            dependencies: ["CoreGraphQLCodegen"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .plugin(
            name: "GenerateGraphQL",
            capability: .command(
                intent: .custom(
                    verb: "generate-graphql",
                    description: "Generate Swift types from a GraphQL schema"
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Write generated GraphQL Swift types")
                ]
            ),
            dependencies: [
                "coregraphql-codegen"
            ]
        ),
        .testTarget(
            name: "CoreGraphQLTests",
            dependencies: ["CoreGraphQL", "CoreGraphQLCodegen"]
        )
    ]
)
