# CoreGraphQL

A small GraphQL client for Swift apps. One object to run queries and mutations over HTTP — without Apollo or codegen.

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

CoreGraphQL is that layer. It is not a new GraphQL runtime. `URLSession` stays in charge.

This package has **no Swift package dependencies**. No subscriptions, no schema codegen, no file uploads.

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
