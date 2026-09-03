# CoreGraphQL

A small GraphQL client for Swift apps. One object to run queries and mutations over HTTP — with file uploads and schema-to-Swift codegen, without Apollo.

[![CI](https://github.com/HirakM/CoreGraphQL/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/HirakM/CoreGraphQL/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20|%20macOS%2014%20|%20tvOS%2017%20|%20watchOS%2010%20|%20visionOS-blue)](Package.swift)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Why this exists

Most Swift apps talk to GraphQL with a huge client, or by hand-rolling `URLSession` JSON:

- POST `query` + `variables` to one endpoint
- decode the `data` object into a model
- map the `errors` array
- attach headers (bearer token, client name)
- send files with the multipart upload spec
- generate Swift types from a schema

CoreGraphQL is that layer. It is not a new GraphQL runtime. `URLSession` stays in charge.

This package has **no Swift package dependencies**. No subscriptions.

## Install

Add the package in Xcode (**File → Add Package Dependencies…**) or in `Package.swift`:

```swift
.package(url: "https://github.com/HirakM/CoreGraphQL.git", from: "1.0.0")
```

```swift
.product(name: "CoreGraphQL", package: "CoreGraphQL")
```

Minimum platforms: iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1.

## Quick start

```swift
import CoreGraphQL

struct User: Decodable {
    var id: String
    var name: String
}

struct UserData: Decodable {
    var user: User
}

struct UserVariables: Encodable {
    var id: String
}

let client = GraphQLClient(endpoint: URL(string: "https://api.example.com/graphql")!)

let data: UserData = try await client.query(
    """
    query User($id: ID!) {
      user(id: $id) { id name }
    }
    """,
    variables: UserVariables(id: "1")
)
```

Mutations use the same POST:

```swift
let updated: UserData = try await client.mutate(
    """
    mutation UpdateUser($name: String!) {
      updateUser(name: $name) { id name }
    }
    """,
    variables: ["name": "Hirak"]
)
```

## Headers

Default headers are `Accept` and `Content-Type` JSON. Add more on the client or per call:

```swift
let client = GraphQLClient(
    configuration: Configuration(
        endpoint: url,
        defaultHeaders: [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer \(token)"
        ]
    )
)
```

```swift
let data: UserData = try await client.query(
    "{ me { id name } }",
    headers: ["X-Client": "ios"]
)
```

Field names match the GraphQL schema (no snake_case conversion). Dates use ISO-8601.

## File uploads

Uses the [GraphQL multipart request spec](https://github.com/jaydenseric/graphql-multipart-request-spec). Keys in `files` are variable paths (`file` or `files.0`).

```swift
let file = GraphQLFile(
    data: imageData,
    filename: "photo.jpg",
    mimeType: "image/jpeg"
)

struct UploadData: Decodable {
    var upload: User
}

let result: UploadData = try await client.upload(
    """
    mutation ($file: Upload!) {
      upload(file: $file) { id name }
    }
    """,
    files: ["file": file]
)
```

`GraphQLFile` encodes as JSON `null`, so it can also live on an `Encodable` variables struct. Still pass it in `files:` so the bytes go in the multipart body.

## Schema codegen

Generates Swift types (objects, inputs, enums, unions, custom scalars) from a `.graphql` SDL file or introspection JSON. No extra packages.

From this repo:

```
swift run coregraphql-codegen --schema schema.graphql --output Sources/Generated/Schema.swift
```

From an app that depends on CoreGraphQL:

```
swift package --allow-writing-to-package-directory generate-graphql \
  --schema schema.graphql \
  --output Sources/Generated/Schema.swift
```

`--access internal` if you do not want `public` types. Custom scalars become `typealias Foo = String`. `Upload` becomes `GraphQLFile`. `ID` becomes `String`.

Add the generated file to your target and `import CoreGraphQL`.

## Errors

```swift
do {
    let data: UserData = try await client.query("{ me { id } }")
} catch GraphQLError.unauthorized {
    // HTTP 401
} catch GraphQLError.operation(let errors) {
    // GraphQL `errors` array (200 with errors, or errors and no data)
} catch GraphQLError.http(let status, let body) {
    // other 4xx / 5xx
} catch GraphQLError.decodingFailed {
    // JSON did not match the model
} catch {
    // transport / cancelled
}
```

If the payload includes a non-empty `errors` array, the client throws `operation` and does not return partial `data`.

## Testing

Inject a `URLSession` whose configuration uses a `URLProtocol` mock. See `Tests/CoreGraphQLTests`.

## Requirements

- Xcode 16+
- Swift 6

## License

MIT. See [LICENSE](LICENSE).
