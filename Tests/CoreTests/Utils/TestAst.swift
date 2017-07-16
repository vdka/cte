@testable import Core

indirect enum TestAst {
    case int(UInt64)
    case ident(String)
    case decl(names: [TestAst], type: TestAst?, values: [TestAst])
}

extension TestAst {
    func expand() -> AstNode {
        let value: AstValue
        switch self {
        case .int(let val):
            value = AstNode.IntegerLiteral(value: val)

        case .ident(let identifier):
            value = AstNode.Identifier(name: identifier)

        case .decl(let names, let type, let values):
            value = AstNode.Declaration(
                names: names.expanded,
                type: type?.expand(),
                values: values.expanded,
                linkName: nil,
                flags: []
            )
        }

        return AstNode(value: value, tokens: [])
    }
}

extension TestAst {
    static func makeDecl(_ name: String, _ type: String?, _ value: String) -> TestAst {
        return makeDecl([name], type, [value])
    }

    static func makeDecl(_ names: [String], _ type: String?, _ values: [String]) -> TestAst {
        return .decl(
            names: names.map { TestAst.ident($0) },
            type: type == nil ? nil : .ident(type!),
            values: values.map { TestAst.ident($0) }
        )
    }

    static func makeDecl(_ name: String, _ type: String?, _ value: UInt64) -> TestAst {
        return makeDecl([name], type, [value])
    }

    static func makeDecl(_ names: [String], _ type: String?, _ values: [UInt64]) -> TestAst {
        return .decl(
            names: names.map { TestAst.ident($0) },
            type: type == nil ? nil : .ident(type!),
            values: values.map { TestAst.int($0) }
        )
    }
}

extension Sequence where Iterator.Element == TestAst {
    var expanded: [AstNode] {
        return self.map({ $0.expand() })
    }
}
