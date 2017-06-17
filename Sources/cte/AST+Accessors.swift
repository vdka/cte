// Generated using Sourcery 0.7.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT (by hand)


extension cte.AstNode.Value {

    var CompileTime: cte.CompileTime {
        get {
            assert(node.kind == cte.CompileTime.astKind)
            return node.value.assumingMemoryBound(to: cte.CompileTime.self).pointee
        }
        set {
            node.kind = cte.CompileTime.astKind
            node.value.assumingMemoryBound(to: cte.CompileTime.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var Declaration: cte.Declaration {
        get {
            assert(node.kind == cte.Declaration.astKind)
            return node.value.assumingMemoryBound(to: cte.Declaration.self).pointee
        }
        set {
            node.kind = cte.Declaration.astKind
            node.value.assumingMemoryBound(to: cte.Declaration.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var Empty: cte.Empty {
        get {
            assert(node.kind == cte.Empty.astKind)
            return node.value.assumingMemoryBound(to: cte.Empty.self).pointee
        }
        set {
            node.kind = cte.Empty.astKind
            node.value.assumingMemoryBound(to: cte.Empty.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var ExprBinary: cte.ExprBinary {
        get {
            assert(node.kind == cte.ExprBinary.astKind)
            return node.value.assumingMemoryBound(to: cte.ExprBinary.self).pointee
        }
        set {
            node.kind = cte.ExprBinary.astKind
            node.value.assumingMemoryBound(to: cte.ExprBinary.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var ExprCall: cte.ExprCall {
        get {
            assert(node.kind == cte.ExprCall.astKind)
            return node.value.assumingMemoryBound(to: cte.ExprCall.self).pointee
        }
        set {
            node.kind = cte.ExprCall.astKind
            node.value.assumingMemoryBound(to: cte.ExprCall.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var ExprParen: cte.ExprParen {
        get {
            assert(node.kind == cte.ExprParen.astKind)
            return node.value.assumingMemoryBound(to: cte.ExprParen.self).pointee
        }
        set {
            node.kind = cte.ExprParen.astKind
            node.value.assumingMemoryBound(to: cte.ExprParen.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var ExprUnary: cte.ExprUnary {
        get {
            assert(node.kind == cte.ExprUnary.astKind)
            return node.value.assumingMemoryBound(to: cte.ExprUnary.self).pointee
        }
        set {
            node.kind = cte.ExprUnary.astKind
            node.value.assumingMemoryBound(to: cte.ExprUnary.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var Function: cte.Function {
        get {
            assert(node.kind == cte.Function.astKind)
            return node.value.assumingMemoryBound(to: cte.Function.self).pointee
        }
        set {
            node.kind = cte.Function.astKind
            node.value.assumingMemoryBound(to: cte.Function.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var Identifier: cte.Identifier {
        get {
            assert(node.kind == cte.Identifier.astKind)
            return node.value.assumingMemoryBound(to: cte.Identifier.self).pointee
        }
        set {
            node.kind = cte.Identifier.astKind
            node.value.assumingMemoryBound(to: cte.Identifier.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var Invalid: cte.Invalid {
        get {
            assert(node.kind == cte.Invalid.astKind)
            return node.value.assumingMemoryBound(to: cte.Invalid.self).pointee
        }
        set {
            node.kind = cte.Invalid.astKind
            node.value.assumingMemoryBound(to: cte.Invalid.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var List: cte.List {
        get {
            assert(node.kind == cte.List.astKind)
            return node.value.assumingMemoryBound(to: cte.List.self).pointee
        }
        set {
            node.kind = cte.List.astKind
            node.value.assumingMemoryBound(to: cte.List.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var NumberLiteral: cte.NumberLiteral {
        get {
            assert(node.kind == cte.NumberLiteral.astKind)
            return node.value.assumingMemoryBound(to: cte.NumberLiteral.self).pointee
        }
        set {
            node.kind = cte.NumberLiteral.astKind
            node.value.assumingMemoryBound(to: cte.NumberLiteral.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var StmtBlock: cte.StmtBlock {
        get {
            assert(node.kind == cte.StmtBlock.astKind)
            return node.value.assumingMemoryBound(to: cte.StmtBlock.self).pointee
        }
        set {
            node.kind = cte.StmtBlock.astKind
            node.value.assumingMemoryBound(to: cte.StmtBlock.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var StmtIf: cte.StmtIf {
        get {
            assert(node.kind == cte.StmtIf.astKind)
            return node.value.assumingMemoryBound(to: cte.StmtIf.self).pointee
        }
        set {
            node.kind = cte.StmtIf.astKind
            node.value.assumingMemoryBound(to: cte.StmtIf.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var StmtReturn: cte.StmtReturn {
        get {
            assert(node.kind == cte.StmtReturn.astKind)
            return node.value.assumingMemoryBound(to: cte.StmtReturn.self).pointee
        }
        set {
            node.kind = cte.StmtReturn.astKind
            node.value.assumingMemoryBound(to: cte.StmtReturn.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }

    var StringLiteral: cte.StringLiteral {
        get {
            assert(node.kind == cte.StringLiteral.astKind)
            return node.value.assumingMemoryBound(to: cte.StringLiteral.self).pointee
        }
        set {
            node.kind = cte.StringLiteral.astKind
            node.value.assumingMemoryBound(to: cte.StringLiteral.self).initialize(to: newValue) // TODO(vdka): Deallocate the previous value
        }
    }
}

let maxBytesForNodeValue = max(
    MemoryLayout<CompileTime>.size,
    MemoryLayout<Declaration>.size,
    MemoryLayout<Empty>.size,
    MemoryLayout<ExprBinary>.size,
    MemoryLayout<ExprCall>.size,
    MemoryLayout<ExprParen>.size,
    MemoryLayout<ExprUnary>.size,
    MemoryLayout<Function>.size,
    MemoryLayout<Identifier>.size,
    MemoryLayout<Invalid>.size,
    MemoryLayout<List>.size,
    MemoryLayout<NumberLiteral>.size,
    MemoryLayout<StmtBlock>.size,
    MemoryLayout<StmtIf>.size,
    MemoryLayout<StmtReturn>.size,
    MemoryLayout<StringLiteral>.size
)

