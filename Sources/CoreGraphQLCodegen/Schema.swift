import Foundation

public enum TypeRef: Equatable, Sendable {
    case named(String, nullable: Bool)
    indirect case list(TypeRef, nullable: Bool)

    public func nonNull() -> TypeRef {
        switch self {
        case .named(let name, _):
            .named(name, nullable: false)
        case .list(let inner, _):
            .list(inner, nullable: false)
        }
    }
}

public struct FieldDef: Equatable, Sendable {
    public var name: String
    public var type: TypeRef
}

public struct ObjectDef: Equatable, Sendable {
    public var name: String
    public var fields: [FieldDef]
}

public struct EnumDef: Equatable, Sendable {
    public var name: String
    public var values: [String]
}

public struct UnionDef: Equatable, Sendable {
    public var name: String
    public var members: [String]
}

public struct GraphQLSchemaDocument: Equatable, Sendable {
    public var scalars: [String]
    public var enums: [EnumDef]
    public var objects: [ObjectDef]
    public var inputs: [ObjectDef]
    public var interfaces: [ObjectDef]
    public var unions: [UnionDef]

    public init(
        scalars: [String] = [],
        enums: [EnumDef] = [],
        objects: [ObjectDef] = [],
        inputs: [ObjectDef] = [],
        interfaces: [ObjectDef] = [],
        unions: [UnionDef] = []
    ) {
        self.scalars = scalars
        self.enums = enums
        self.objects = objects
        self.inputs = inputs
        self.interfaces = interfaces
        self.unions = unions
    }
}

public enum CodegenError: Error, Equatable, LocalizedError, Sendable {
    case invalidSchema(String)
    case missingArgument(String)
    case io(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSchema(let message), .missingArgument(let message), .io(let message):
            message
        }
    }
}
