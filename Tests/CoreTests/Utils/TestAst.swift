@testable import Core

indirect enum TestAst {
    case int(UInt64)
    case double(Double)
    case string(String)
    case ident(String)
    case decl(names: [TestAst], type: TestAst?, values: [TestAst])
}

extension TestAst {
    func expand() -> AstNode {
        let value: AstValue
        switch self {
        case .int(let val):
            value = AstNode.IntegerLiteral(value: val)

        case .double(let val):
            value = AstNode.FloatLiteral(value: val)

        case .string(let val):
            value = AstNode.StringLiteral(value: val)

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

protocol TestLiteralRepresentable {
    func toLiteral() -> TestAst
}

extension String: TestLiteralRepresentable {
    func toLiteral() -> TestAst {
        return .string(self)
    }
}

extension UInt64: TestLiteralRepresentable {
    func toLiteral() -> TestAst {
        return .int(self)
    }
}

extension Double: TestLiteralRepresentable {
    func toLiteral() -> TestAst {
        return .double(self)
    }
}

extension TestAst: TestLiteralRepresentable {
    func toLiteral() -> TestAst {
        return self
    }
}

extension TestAst {
    static func makeDecl<T: TestLiteralRepresentable>(_ names: String, _ type: String? = nil, val value: T) -> TestAst {
        return makeDecl([names], type, values: [value])
    }

    static func makeDecl<T: TestLiteralRepresentable>(_ names: [String], _ type: String? = nil, values: [T]) -> TestAst {
        return .decl(
            names: names.map { TestAst.ident($0) },
            type: type == nil ? nil : .ident(type!),
            values: values.map { $0.toLiteral() }
        )
    }
}

extension Sequence where Iterator.Element == TestAst {
    var expanded: [AstNode] {
        return self.map({ $0.expand() })
    }
}
