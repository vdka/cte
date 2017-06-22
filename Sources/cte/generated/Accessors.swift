// Generated using Sourcery 0.7.2 — https://github.com/krzysztofzablocki/Sourcery
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

    var asFloatLiteral: CommonFloatLiteral {
        assert(kind == AstNode.FloatLiteral.astKind)
        return value as! CommonFloatLiteral
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

    var asIntegerLiteral: CommonIntegerLiteral {
        assert(kind == AstNode.IntegerLiteral.astKind)
        return value as! CommonIntegerLiteral
    }

    var asInvalid: CommonInvalid {
        assert(kind == AstNode.Invalid.astKind)
        return value as! CommonInvalid
    }

    var asParen: CommonParen {
        assert(kind == AstNode.Paren.astKind)
        return value as! CommonParen
    }

    var asPointerType: CommonPointerType {
        assert(kind == AstNode.PointerType.astKind)
        return value as! CommonPointerType
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

    var asCheckedFloatLiteral: Checker.FloatLiteral {
        assert(kind == Checker.FloatLiteral.astKind)
        return value as! Checker.FloatLiteral
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

    var asCheckedIntegerLiteral: Checker.IntegerLiteral {
        assert(kind == Checker.IntegerLiteral.astKind)
        return value as! Checker.IntegerLiteral
    }

    var asCheckedParen: Checker.Paren {
        assert(kind == Checker.Paren.astKind)
        return value as! Checker.Paren
    }

    var asCheckedPointerType: Checker.PointerType {
        assert(kind == Checker.PointerType.astKind)
        return value as! Checker.PointerType
    }

    var asCheckedPolymorphicFunction: Checker.PolymorphicFunction {
        assert(kind == Checker.PolymorphicFunction.astKind)
        return value as! Checker.PolymorphicFunction
    }

    var asCheckedPrefix: Checker.Prefix {
        assert(kind == Checker.Prefix.astKind)
        return value as! Checker.Prefix
    }

    var asCheckedStringLiteral: Checker.StringLiteral {
        assert(kind == Checker.StringLiteral.astKind)
        return value as! Checker.StringLiteral
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

protocol CommonFloatLiteral {

    var value: Double { get }
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

protocol CommonIntegerLiteral {

    var value: UInt64 { get }
}

protocol CommonInvalid {

}

protocol CommonParen {

    var expr: AstNode { get }
}

protocol CommonPointerType {

    var pointee: AstNode { get }
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

extension AstNode.FloatLiteral: CommonFloatLiteral {}

extension AstNode.Function: CommonFunction {}

extension AstNode.Identifier: CommonIdentifier {}

extension AstNode.If: CommonIf {}

extension AstNode.Infix: CommonInfix {}

extension AstNode.IntegerLiteral: CommonIntegerLiteral {}

extension AstNode.Invalid: CommonInvalid {}

extension AstNode.Paren: CommonParen {}

extension AstNode.PointerType: CommonPointerType {}

extension AstNode.Prefix: CommonPrefix {}

extension AstNode.Return: CommonReturn {}

extension AstNode.StringLiteral: CommonStringLiteral {}

extension Checker.Block: CommonBlock {}

extension Checker.Call: CommonCall {}

extension Checker.Declaration: CommonDeclaration {}

extension Checker.FloatLiteral: CommonFloatLiteral {}

extension Checker.Function: CommonFunction {}

extension Checker.Identifier: CommonIdentifier {}

extension Checker.Infix: CommonInfix {}

extension Checker.IntegerLiteral: CommonIntegerLiteral {}

extension Checker.Paren: CommonParen {}

extension Checker.PointerType: CommonPointerType {}

extension Checker.Prefix: CommonPrefix {}

extension Checker.StringLiteral: CommonStringLiteral {}

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

    var asPointer: Type.Pointer {
        return value as! Type.Pointer
    }
}
