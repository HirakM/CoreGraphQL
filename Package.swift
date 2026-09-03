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
        .library(name: "CoreGraphQL", targets: ["CoreGraphQL"])
    ],
    targets: [
        .target(
            name: "CoreGraphQL",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "CoreGraphQLTests",
            dependencies: ["CoreGraphQL"]
        )
    ]
)
