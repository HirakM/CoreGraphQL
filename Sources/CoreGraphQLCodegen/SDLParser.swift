import Foundation

public enum SDLParser {
    public static func parse(_ source: String) throws -> GraphQLSchemaDocument {
        var parser = Parser(lexer: Lexer(source: source))
        return try parser.parseDocument()
    }
}

private struct Token: Equatable {
    enum Kind: Equatable {
        case ident(String)
        case punct(Character)
        case eof
    }

    var kind: Kind
}

private struct Lexer {
    private let chars: [Character]
    private var index = 0

    init(source: String) {
        chars = Array(source)
    }

    mutating func next() throws -> Token {
        skipTrivia()
        guard index < chars.count else { return Token(kind: .eof) }

        let char = chars[index]
        if char == ".", peek(1) == ".", peek(2) == "." {
            index += 3
            return Token(kind: .punct("."))
        }
        if "{}()[]:!|=&@,".contains(char) {
            index += 1
            return Token(kind: .punct(char))
        }
        if char == "_" || char.isLetter {
            return Token(kind: .ident(readName()))
        }
        if char == "-" || char.isNumber {
            readWhile { $0.isNumber || $0 == "." || $0 == "-" || $0 == "e" || $0 == "E" || $0 == "+" }
            return Token(kind: .ident("0"))
        }
        throw CodegenError.invalidSchema("Unexpected character '\(char)' in GraphQL schema.")
    }

    private mutating func skipTrivia() {
        while index < chars.count {
            let char = chars[index]
            if char.isWhitespace {
                index += 1
                continue
            }
            if char == "#" {
                while index < chars.count, chars[index] != "\n" {
                    index += 1
                }
                continue
            }
            if char == "\"", peek(1) == "\"", peek(2) == "\"" {
                index += 3
                skipBlockString()
                continue
            }
            if char == "\"" {
                index += 1
                skipString()
                continue
            }
            break
        }
    }

    private mutating func skipString() {
        while index < chars.count {
            let char = chars[index]
            index += 1
            if char == "\\" { index += 1; continue }
            if char == "\"" { break }
        }
    }

    private mutating func skipBlockString() {
        while index + 2 < chars.count {
            if chars[index] == "\"", chars[index + 1] == "\"", chars[index + 2] == "\"" {
                index += 3
                return
            }
            index += 1
        }
        index = chars.count
    }

    private mutating func readName() -> String {
        let start = index
        index += 1
        while index < chars.count {
            let char = chars[index]
            if char == "_" || char.isLetter || char.isNumber {
                index += 1
            } else {
                break
            }
        }
        return String(chars[start..<index])
    }

    private mutating func readWhile(_ predicate: (Character) -> Bool) {
        while index < chars.count, predicate(chars[index]) {
            index += 1
        }
    }

    private func peek(_ offset: Int) -> Character? {
        let i = index + offset
        guard i < chars.count else { return nil }
        return chars[i]
    }
}

private struct Parser {
    private var lexer: Lexer
    private var current: Token

    init(lexer: Lexer) {
        self.lexer = lexer
        self.current = Token(kind: .eof)
    }

    mutating func parseDocument() throws -> GraphQLSchemaDocument {
        current = try lexer.next()
        var document = GraphQLSchemaDocument()

        while current.kind != .eof {
            if takeIdent("extend") {
                try skipExtendedDefinition()
                continue
            }
            if takeIdent("schema") || takeIdent("directive") {
                try skipDefinition()
                continue
            }
            if takeIdent("scalar") {
                let name = try expectIdent()
                try skipDirectives()
                if !isBuiltinScalar(name), !name.hasPrefix("__") {
                    document.scalars.append(name)
                }
                continue
            }
            if takeIdent("enum") {
                let name = try expectIdent()
                try skipDirectives()
                try expectPunct("{")
                var values: [String] = []
                while !takePunct("}") {
                    values.append(try expectIdent())
                    try skipDirectives()
                }
                if !name.hasPrefix("__") {
                    document.enums.append(EnumDef(name: name, values: values))
                }
                continue
            }
            if takeIdent("union") {
                let name = try expectIdent()
                try skipDirectives()
                try expectPunct("=")
                _ = takePunct("|")
                var members = [try expectIdent()]
                while takePunct("|") {
                    members.append(try expectIdent())
                }
                if !name.hasPrefix("__") {
                    document.unions.append(UnionDef(name: name, members: members))
                }
                continue
            }
            if takeIdent("input") {
                let name = try expectIdent()
                try skipDirectives()
                let fields = try parseFieldSet()
                if !name.hasPrefix("__") {
                    document.inputs.append(ObjectDef(name: name, fields: fields))
                }
                continue
            }
            if takeIdent("interface") {
                let name = try expectIdent()
                try skipImplements()
                try skipDirectives()
                let fields = try parseFieldSet()
                if !name.hasPrefix("__") {
                    document.interfaces.append(ObjectDef(name: name, fields: fields))
                }
                continue
            }
            if takeIdent("type") {
                let name = try expectIdent()
                try skipImplements()
                try skipDirectives()
                let fields = try parseFieldSet()
                if !name.hasPrefix("__") {
                    document.objects.append(ObjectDef(name: name, fields: fields))
                }
                continue
            }
            throw CodegenError.invalidSchema("Unexpected token in schema: \(current.kind).")
        }

        return document
    }

    private mutating func parseFieldSet() throws -> [FieldDef] {
        try expectPunct("{")
        var fields: [FieldDef] = []
        while !takePunct("}") {
            let name = try expectIdent()
            if takePunct("(") {
                try skipBalanced()
            }
            try expectPunct(":")
            let type = try parseType()
            try skipDirectives()
            if takePunct("=") {
                try skipValue()
            }
            fields.append(FieldDef(name: name, type: type))
        }
        return fields
    }

    private mutating func parseType() throws -> TypeRef {
        if takePunct("[") {
            let inner = try parseType()
            try expectPunct("]")
            let nullable = !takePunct("!")
            return .list(inner, nullable: nullable)
        }
        let name = try expectIdent()
        let nullable = !takePunct("!")
        return .named(name, nullable: nullable)
    }

    private mutating func skipExtendedDefinition() throws {
        _ = takeIdent("type")
            || takeIdent("input")
            || takeIdent("enum")
            || takeIdent("interface")
            || takeIdent("union")
            || takeIdent("scalar")
            || takeIdent("schema")
        if case .ident = current.kind {
            consume()
        }
        try skipImplements()
        try skipDirectives()
        if takePunct("{") {
            try skipBalanced()
        }
        if takePunct("=") {
            while current.kind != .eof, !isDefinitionKeyword {
                consume()
            }
        }
    }

    private mutating func skipDefinition() throws {
        try skipDirectives()
        if takePunct("{") {
            try skipBalanced()
        } else if takePunct("(") {
            try skipBalanced()
            try skipDirectives()
            if takePunct("{") {
                try skipBalanced()
            }
        }
    }

    private var isDefinitionKeyword: Bool {
        if case .ident(let name) = current.kind {
            return ["type", "input", "enum", "scalar", "union", "interface", "schema", "directive", "extend"].contains(name)
        }
        return false
    }

    private mutating func skipImplements() throws {
        guard takeIdent("implements") else { return }
        _ = takePunct("&")
        _ = try expectIdent()
        while takePunct("&") {
            _ = try expectIdent()
        }
    }

    private mutating func skipDirectives() throws {
        while takePunct("@") {
            _ = try expectIdent()
            if takePunct("(") {
                try skipBalanced()
            }
        }
    }

    private mutating func skipValue() throws {
        if takePunct("[") {
            while !takePunct("]") {
                try skipValue()
                _ = takePunct(",")
            }
            return
        }
        if takePunct("{") {
            while !takePunct("}") {
                _ = try expectIdent()
                try expectPunct(":")
                try skipValue()
                _ = takePunct(",")
            }
            return
        }
        if takePunct("$") {
            _ = try expectIdent()
            return
        }
        current = try lexer.next()
    }

    private mutating func skipBalanced() throws {
        var depth = 1
        while current.kind != .eof, depth > 0 {
            if takePunct("{") || takePunct("(") || takePunct("[") {
                depth += 1
                continue
            }
            if takePunct("}") || takePunct(")") || takePunct("]") {
                depth -= 1
                continue
            }
            consume()
        }
    }

    private mutating func takeIdent(_ value: String) -> Bool {
        if case .ident(let name) = current.kind, name == value {
            consume()
            return true
        }
        return false
    }

    private mutating func takePunct(_ value: Character) -> Bool {
        if case .punct(let char) = current.kind, char == value {
            consume()
            return true
        }
        return false
    }

    private mutating func expectIdent() throws -> String {
        if case .ident(let name) = current.kind {
            consume()
            return name
        }
        throw CodegenError.invalidSchema("Expected a name in the GraphQL schema.")
    }

    private mutating func expectPunct(_ value: Character) throws {
        guard takePunct(value) else {
            throw CodegenError.invalidSchema("Expected '\(value)' in the GraphQL schema.")
        }
    }

    private mutating func consume() {
        do {
            current = try lexer.next()
        } catch {
            current = Token(kind: .eof)
        }
    }
}

private func isBuiltinScalar(_ name: String) -> Bool {
    ["String", "Int", "Float", "Boolean", "ID"].contains(name)
}
