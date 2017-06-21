// Generated using Sourcery 0.7.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



extension AstNode {

    var asBlock: CommonBlock {
        assert(kind == AstNode.Block.astKind)
        return value as! CommonBlock
    }

    var asCall: CommonCall {
        assert(kind == AstNode.Call.astKind)
        return value as! CommonCall
    }

    var asDeclaration: CommonDeclaration {
        assert(kind == AstNode.Declaration.astKind)
        return value as! CommonDeclaration
    }

    var asEmpty: CommonEmpty {
        assert(kind == AstNode.Empty.astKind)
        return value as! CommonEmpty
    }

    var asFunction: CommonFunction {
        assert(kind == AstNode.Function.astKind)
        return value as! CommonFunction
    }

    var asIdentifier: CommonIdentifier {
        assert(kind == AstNode.Identifier.astKind)
        return value as! CommonIdentifier
    }

    var asIf: CommonIf {
        assert(kind == AstNode.If.astKind)
        return value as! CommonIf
    }

    var asInfix: CommonInfix {
        assert(kind == AstNode.Infix.astKind)
        return value as! CommonInfix
    }

    var asInvalid: CommonInvalid {
        assert(kind == AstNode.Invalid.astKind)
        return value as! CommonInvalid
    }

    var asNumberLiteral: CommonNumberLiteral {
        assert(kind == AstNode.NumberLiteral.astKind)
        return value as! CommonNumberLiteral
    }

    var asParen: CommonParen {
        assert(kind == AstNode.Paren.astKind)
        return value as! CommonParen
    }

    var asPrefix: CommonPrefix {
        assert(kind == AstNode.Prefix.astKind)
        return value as! CommonPrefix
    }

    var asReturn: CommonReturn {
        assert(kind == AstNode.Return.astKind)
        return value as! CommonReturn
    }

    var asStringLiteral: CommonStringLiteral {
        assert(kind == AstNode.StringLiteral.astKind)
        return value as! CommonStringLiteral
    }

    var asCheckedBlock: Checker.Block {
        assert(kind == Checker.Block.astKind)
        return value as! Checker.Block
    }

    var asCheckedCall: Checker.Call {
        assert(kind == Checker.Call.astKind)
        return value as! Checker.Call
    }

    var asCheckedDeclaration: Checker.Declaration {
        assert(kind == Checker.Declaration.astKind)
        return value as! Checker.Declaration
    }

    var asCheckedFunction: Checker.Function {
        assert(kind == Checker.Function.astKind)
        return value as! Checker.Function
    }

    var asCheckedIdentifier: Checker.Identifier {
        assert(kind == Checker.Identifier.astKind)
        return value as! Checker.Identifier
    }

    var asCheckedInfix: Checker.Infix {
        assert(kind == Checker.Infix.astKind)
        return value as! Checker.Infix
    }

    var asCheckedParen: Checker.Paren {
        assert(kind == Checker.Paren.astKind)
        return value as! Checker.Paren
    }

    var asCheckedPolymorphicFunction: Checker.PolymorphicFunction {
        assert(kind == Checker.PolymorphicFunction.astKind)
        return value as! Checker.PolymorphicFunction
    }

    var asCheckedPrefix: Checker.Prefix {
        assert(kind == Checker.Prefix.astKind)
        return value as! Checker.Prefix
    }
}


protocol CommonBlock {

    var stmts: [AstNode] { get }
}

protocol CommonCall {

    var callee: AstNode { get }
    var arguments: [AstNode] { get }
}

protocol CommonDeclaration {

    var identifier: AstNode { get }
    var type: AstNode? { get }
    var value: AstNode { get }
    var isCompileTime: Bool { get }
}

protocol CommonEmpty {

}

protocol CommonFunction {

    var parameters: [AstNode] { get }
    var returnType: AstNode { get }
    var body: AstNode { get }
}

protocol CommonIdentifier {

    var name: String { get }
}

protocol CommonIf {

    var condition: AstNode { get }
    var thenStmt: AstNode { get }
    var elseStmt: AstNode? { get }
}

protocol CommonInfix {

    var kind: Token.Kind { get }
    var lhs: AstNode { get }
    var rhs: AstNode { get }
}

protocol CommonInvalid {

}

protocol CommonNumberLiteral {

    var value: Double { get }
}

protocol CommonParen {

    var expr: AstNode { get }
}

protocol CommonPrefix {

    var kind: Token.Kind { get }
    var expr: AstNode { get }
}

protocol CommonReturn {

    var value: AstNode { get }
}

protocol CommonStringLiteral {

    var value: String { get }
}


extension AstNode.Block: CommonBlock {}

extension AstNode.Call: CommonCall {}

extension AstNode.Declaration: CommonDeclaration {}

extension AstNode.Empty: CommonEmpty {}

extension AstNode.Function: CommonFunction {}

extension AstNode.Identifier: CommonIdentifier {}

extension AstNode.If: CommonIf {}

extension AstNode.Infix: CommonInfix {}

extension AstNode.Invalid: CommonInvalid {}

extension AstNode.NumberLiteral: CommonNumberLiteral {}

extension AstNode.Paren: CommonParen {}

extension AstNode.Prefix: CommonPrefix {}

extension AstNode.Return: CommonReturn {}

extension AstNode.StringLiteral: CommonStringLiteral {}

extension Checker.Block: CommonBlock {}

extension Checker.Call: CommonCall {}

extension Checker.Declaration: CommonDeclaration {}

extension Checker.Function: CommonFunction {}

extension Checker.Identifier: CommonIdentifier {}

extension Checker.Infix: CommonInfix {}

extension Checker.Paren: CommonParen {}

extension Checker.Prefix: CommonPrefix {}

extension Type {

    var asBuiltin: Type.Builtin {
        return value as! Type.Builtin
    }

    var asFunction: Type.Function {
        return value as! Type.Function
    }

    var asMetatype: Type.Metatype {
        return value as! Type.Metatype
    }
}
