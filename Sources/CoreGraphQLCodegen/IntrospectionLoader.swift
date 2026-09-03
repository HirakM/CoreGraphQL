import Foundation

public enum IntrospectionLoader {
    public static func load(from data: Data) throws -> GraphQLSchemaDocument {
        let decoded: File
        do {
            decoded = try JSONDecoder().decode(File.self, from: data)
        } catch {
            throw CodegenError.invalidSchema("Introspection JSON could not be decoded.")
        }
        guard let schema = decoded.data?.__schema ?? decoded.__schema else {
            throw CodegenError.invalidSchema("Introspection JSON is missing __schema.")
        }
        return convert(schema)
    }

    private static func convert(_ schema: Schema) -> GraphQLSchemaDocument {
        var document = GraphQLSchemaDocument()
        for type in schema.types where !(type.name ?? "").hasPrefix("__") {
            switch type.kind {
            case "SCALAR":
                if let name = type.name, !["String", "Int", "Float", "Boolean", "ID"].contains(name) {
                    document.scalars.append(name)
                }
            case "ENUM":
                if let name = type.name {
                    document.enums.append(
                        EnumDef(name: name, values: (type.enumValues ?? []).map(\.name))
                    )
                }
            case "OBJECT":
                if let name = type.name {
                    document.objects.append(
                        ObjectDef(name: name, fields: (type.fields ?? []).compactMap(convertField))
                    )
                }
            case "INPUT_OBJECT":
                if let name = type.name {
                    document.inputs.append(
                        ObjectDef(name: name, fields: (type.inputFields ?? []).compactMap(convertInput))
                    )
                }
            case "INTERFACE":
                if let name = type.name {
                    document.interfaces.append(
                        ObjectDef(name: name, fields: (type.fields ?? []).compactMap(convertField))
                    )
                }
            case "UNION":
                if let name = type.name {
                    document.unions.append(
                        UnionDef(name: name, members: (type.possibleTypes ?? []).compactMap(\.name))
                    )
                }
            default:
                continue
            }
        }
        return document
    }

    private static func convertField(_ field: Field) -> FieldDef? {
        guard let type = convertType(field.type) else { return nil }
        return FieldDef(name: field.name, type: type)
    }

    private static func convertInput(_ field: InputValue) -> FieldDef? {
        guard let type = convertType(field.type) else { return nil }
        return FieldDef(name: field.name, type: type)
    }

    private static func convertType(_ type: TypeRefJSON?) -> TypeRef? {
        guard let type else { return nil }
        switch type.kind {
        case "NON_NULL":
            return convertType(type.ofType)?.nonNull()
        case "LIST":
            guard let inner = convertType(type.ofType) else { return nil }
            return .list(inner, nullable: true)
        default:
            guard let name = type.name else { return nil }
            return .named(name, nullable: true)
        }
    }
}

private struct File: Decodable {
    var data: DataWrapper?
    var __schema: Schema?
}

private struct DataWrapper: Decodable {
    var __schema: Schema
}

private struct Schema: Decodable {
    var types: [Type]
}

private struct Type: Decodable {
    var kind: String
    var name: String?
    var fields: [Field]?
    var inputFields: [InputValue]?
    var enumValues: [EnumValue]?
    var possibleTypes: [TypeRefJSON]?
}

private struct Field: Decodable {
    var name: String
    var type: TypeRefJSON
}

private struct InputValue: Decodable {
    var name: String
    var type: TypeRefJSON
}

private struct EnumValue: Decodable {
    var name: String
}

private final class TypeRefJSON: Decodable {
    var kind: String
    var name: String?
    var ofType: TypeRefJSON?

    enum CodingKeys: String, CodingKey {
        case kind, name, ofType
    }
}
