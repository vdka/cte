// Generated using Sourcery 0.7.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



extension AstNode {

    var asBlock: AstNode.Block {
        assert(kind == AstNode.Block.astKind)
        return value as! AstNode.Block
    }

    var asCall: AstNode.Call {
        assert(kind == AstNode.Call.astKind)
        return value as! AstNode.Call
    }

    var asDeclaration: AstNode.Declaration {
        assert(kind == AstNode.Declaration.astKind)
        return value as! AstNode.Declaration
    }

    var asEmpty: AstNode.Empty {
        assert(kind == AstNode.Empty.astKind)
        return value as! AstNode.Empty
    }

    var asFunction: AstNode.Function {
        assert(kind == AstNode.Function.astKind)
        return value as! AstNode.Function
    }

    var asIdentifier: AstNode.Identifier {
        assert(kind == AstNode.Identifier.astKind)
        return value as! AstNode.Identifier
    }

    var asIf: AstNode.If {
        assert(kind == AstNode.If.astKind)
        return value as! AstNode.If
    }

    var asInfix: AstNode.Infix {
        assert(kind == AstNode.Infix.astKind)
        return value as! AstNode.Infix
    }

    var asInvalid: AstNode.Invalid {
        assert(kind == AstNode.Invalid.astKind)
        return value as! AstNode.Invalid
    }

    var asNumberLiteral: AstNode.NumberLiteral {
        assert(kind == AstNode.NumberLiteral.astKind)
        return value as! AstNode.NumberLiteral
    }

    var asParen: AstNode.Paren {
        assert(kind == AstNode.Paren.astKind)
        return value as! AstNode.Paren
    }

    var asPrefix: AstNode.Prefix {
        assert(kind == AstNode.Prefix.astKind)
        return value as! AstNode.Prefix
    }

    var asReturn: AstNode.Return {
        assert(kind == AstNode.Return.astKind)
        return value as! AstNode.Return
    }

    var asStringLiteral: AstNode.StringLiteral {
        assert(kind == AstNode.StringLiteral.astKind)
        return value as! AstNode.StringLiteral
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
