// Generated using Sourcery 0.7.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



extension AstNode {

    var asBlock: AstNode.Block {
        get {
            assert(kind == AstNode.Block.astKind)
            return value.baseAddress!.assumingMemoryBound(to: AstNode.Block.self).pointee
        }
        set {
            kind = AstNode.Block.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<AstNode.Block>.size)
            value.baseAddress!.assumingMemoryBound(to: AstNode.Block.self).initialize(to: newValue)
        }
    }

    var asCall: AstNode.Call {
        get {
            assert(kind == AstNode.Call.astKind)
            return value.baseAddress!.assumingMemoryBound(to: AstNode.Call.self).pointee
        }
        set {
            kind = AstNode.Call.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<AstNode.Call>.size)
            value.baseAddress!.assumingMemoryBound(to: AstNode.Call.self).initialize(to: newValue)
        }
    }

    var asDeclaration: AstNode.Declaration {
        get {
            assert(kind == AstNode.Declaration.astKind)
            return value.baseAddress!.assumingMemoryBound(to: AstNode.Declaration.self).pointee
        }
        set {
            kind = AstNode.Declaration.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<AstNode.Declaration>.size)
            value.baseAddress!.assumingMemoryBound(to: AstNode.Declaration.self).initialize(to: newValue)
        }
    }

    var asEmpty: AstNode.Empty {
        get {
            assert(kind == AstNode.Empty.astKind)
            return value.baseAddress!.assumingMemoryBound(to: AstNode.Empty.self).pointee
        }
        set {
            kind = AstNode.Empty.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<AstNode.Empty>.size)
            value.baseAddress!.assumingMemoryBound(to: AstNode.Empty.self).initialize(to: newValue)
        }
    }

    var asFunction: AstNode.Function {
        get {
            assert(kind == AstNode.Function.astKind)
            return value.baseAddress!.assumingMemoryBound(to: AstNode.Function.self).pointee
        }
        set {
            kind = AstNode.Function.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<AstNode.Function>.size)
            value.baseAddress!.assumingMemoryBound(to: AstNode.Function.self).initialize(to: newValue)
        }
    }

    var asIdentifier: AstNode.Identifier {
        get {
            assert(kind == AstNode.Identifier.astKind)
            return value.baseAddress!.assumingMemoryBound(to: AstNode.Identifier.self).pointee
        }
        set {
            kind = AstNode.Identifier.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<AstNode.Identifier>.size)
            value.baseAddress!.assumingMemoryBound(to: AstNode.Identifier.self).initialize(to: newValue)
        }
    }

    var asIf: AstNode.If {
        get {
            assert(kind == AstNode.If.astKind)
            return value.baseAddress!.assumingMemoryBound(to: AstNode.If.self).pointee
        }
        set {
            kind = AstNode.If.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<AstNode.If>.size)
            value.baseAddress!.assumingMemoryBound(to: AstNode.If.self).initialize(to: newValue)
        }
    }

    var asInfix: AstNode.Infix {
        get {
            assert(kind == AstNode.Infix.astKind)
            return value.baseAddress!.assumingMemoryBound(to: AstNode.Infix.self).pointee
        }
        set {
            kind = AstNode.Infix.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<AstNode.Infix>.size)
            value.baseAddress!.assumingMemoryBound(to: AstNode.Infix.self).initialize(to: newValue)
        }
    }

    var asInvalid: AstNode.Invalid {
        get {
            assert(kind == AstNode.Invalid.astKind)
            return value.baseAddress!.assumingMemoryBound(to: AstNode.Invalid.self).pointee
        }
        set {
            kind = AstNode.Invalid.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<AstNode.Invalid>.size)
            value.baseAddress!.assumingMemoryBound(to: AstNode.Invalid.self).initialize(to: newValue)
        }
    }

    var asNumberLiteral: AstNode.NumberLiteral {
        get {
            assert(kind == AstNode.NumberLiteral.astKind)
            return value.baseAddress!.assumingMemoryBound(to: AstNode.NumberLiteral.self).pointee
        }
        set {
            kind = AstNode.NumberLiteral.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<AstNode.NumberLiteral>.size)
            value.baseAddress!.assumingMemoryBound(to: AstNode.NumberLiteral.self).initialize(to: newValue)
        }
    }

    var asParen: AstNode.Paren {
        get {
            assert(kind == AstNode.Paren.astKind)
            return value.baseAddress!.assumingMemoryBound(to: AstNode.Paren.self).pointee
        }
        set {
            kind = AstNode.Paren.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<AstNode.Paren>.size)
            value.baseAddress!.assumingMemoryBound(to: AstNode.Paren.self).initialize(to: newValue)
        }
    }

    var asPrefix: AstNode.Prefix {
        get {
            assert(kind == AstNode.Prefix.astKind)
            return value.baseAddress!.assumingMemoryBound(to: AstNode.Prefix.self).pointee
        }
        set {
            kind = AstNode.Prefix.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<AstNode.Prefix>.size)
            value.baseAddress!.assumingMemoryBound(to: AstNode.Prefix.self).initialize(to: newValue)
        }
    }

    var asReturn: AstNode.Return {
        get {
            assert(kind == AstNode.Return.astKind)
            return value.baseAddress!.assumingMemoryBound(to: AstNode.Return.self).pointee
        }
        set {
            kind = AstNode.Return.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<AstNode.Return>.size)
            value.baseAddress!.assumingMemoryBound(to: AstNode.Return.self).initialize(to: newValue)
        }
    }

    var asStringLiteral: AstNode.StringLiteral {
        get {
            assert(kind == AstNode.StringLiteral.astKind)
            return value.baseAddress!.assumingMemoryBound(to: AstNode.StringLiteral.self).pointee
        }
        set {
            kind = AstNode.StringLiteral.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<AstNode.StringLiteral>.size)
            value.baseAddress!.assumingMemoryBound(to: AstNode.StringLiteral.self).initialize(to: newValue)
        }
    }

    var asCheckedBlock: Checker.Block {
        get {
            assert(kind == Checker.Block.astKind)
            return value.baseAddress!.assumingMemoryBound(to: Checker.Block.self).pointee
        }
        set {
            kind = Checker.Block.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<Checker.Block>.size)
            value.baseAddress!.assumingMemoryBound(to: Checker.Block.self).initialize(to: newValue)
        }
    }

    var asCheckedCall: Checker.Call {
        get {
            assert(kind == Checker.Call.astKind)
            return value.baseAddress!.assumingMemoryBound(to: Checker.Call.self).pointee
        }
        set {
            kind = Checker.Call.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<Checker.Call>.size)
            value.baseAddress!.assumingMemoryBound(to: Checker.Call.self).initialize(to: newValue)
        }
    }

    var asCheckedDeclaration: Checker.Declaration {
        get {
            assert(kind == Checker.Declaration.astKind)
            return value.baseAddress!.assumingMemoryBound(to: Checker.Declaration.self).pointee
        }
        set {
            kind = Checker.Declaration.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<Checker.Declaration>.size)
            value.baseAddress!.assumingMemoryBound(to: Checker.Declaration.self).initialize(to: newValue)
        }
    }

    var asCheckedFunction: Checker.Function {
        get {
            assert(kind == Checker.Function.astKind)
            return value.baseAddress!.assumingMemoryBound(to: Checker.Function.self).pointee
        }
        set {
            kind = Checker.Function.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<Checker.Function>.size)
            value.baseAddress!.assumingMemoryBound(to: Checker.Function.self).initialize(to: newValue)
        }
    }

    var asCheckedIdentifier: Checker.Identifier {
        get {
            assert(kind == Checker.Identifier.astKind)
            return value.baseAddress!.assumingMemoryBound(to: Checker.Identifier.self).pointee
        }
        set {
            kind = Checker.Identifier.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<Checker.Identifier>.size)
            value.baseAddress!.assumingMemoryBound(to: Checker.Identifier.self).initialize(to: newValue)
        }
    }

    var asCheckedInfix: Checker.Infix {
        get {
            assert(kind == Checker.Infix.astKind)
            return value.baseAddress!.assumingMemoryBound(to: Checker.Infix.self).pointee
        }
        set {
            kind = Checker.Infix.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<Checker.Infix>.size)
            value.baseAddress!.assumingMemoryBound(to: Checker.Infix.self).initialize(to: newValue)
        }
    }

    var asCheckedParen: Checker.Paren {
        get {
            assert(kind == Checker.Paren.astKind)
            return value.baseAddress!.assumingMemoryBound(to: Checker.Paren.self).pointee
        }
        set {
            kind = Checker.Paren.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<Checker.Paren>.size)
            value.baseAddress!.assumingMemoryBound(to: Checker.Paren.self).initialize(to: newValue)
        }
    }

    var asCheckedPolymorphicFunction: Checker.PolymorphicFunction {
        get {
            assert(kind == Checker.PolymorphicFunction.astKind)
            return value.baseAddress!.assumingMemoryBound(to: Checker.PolymorphicFunction.self).pointee
        }
        set {
            kind = Checker.PolymorphicFunction.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<Checker.PolymorphicFunction>.size)
            value.baseAddress!.assumingMemoryBound(to: Checker.PolymorphicFunction.self).initialize(to: newValue)
        }
    }

    var asCheckedPrefix: Checker.Prefix {
        get {
            assert(kind == Checker.Prefix.astKind)
            return value.baseAddress!.assumingMemoryBound(to: Checker.Prefix.self).pointee
        }
        set {
            kind = Checker.Prefix.astKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<Checker.Prefix>.size)
            value.baseAddress!.assumingMemoryBound(to: Checker.Prefix.self).initialize(to: newValue)
        }
    }
}

extension AstNode.Block {
    var isChecked: Bool {
        return false
    }
}

extension AstNode.Call {
    var isChecked: Bool {
        return false
    }
}

extension AstNode.Declaration {
    var isChecked: Bool {
        return false
    }
}

extension AstNode.Empty {
    var isChecked: Bool {
        return false
    }
}

extension AstNode.Function {
    var isChecked: Bool {
        return false
    }
}

extension AstNode.Identifier {
    var isChecked: Bool {
        return false
    }
}

extension AstNode.If {
    var isChecked: Bool {
        return false
    }
}

extension AstNode.Infix {
    var isChecked: Bool {
        return false
    }
}

extension AstNode.Invalid {
    var isChecked: Bool {
        return false
    }
}

extension AstNode.NumberLiteral {
    var isChecked: Bool {
        return false
    }
}

extension AstNode.Paren {
    var isChecked: Bool {
        return false
    }
}

extension AstNode.Prefix {
    var isChecked: Bool {
        return false
    }
}

extension AstNode.Return {
    var isChecked: Bool {
        return false
    }
}

extension AstNode.StringLiteral {
    var isChecked: Bool {
        return false
    }
}

extension Checker.Block {
    var isChecked: Bool {
        return true
    }
}

extension Checker.Call {
    var isChecked: Bool {
        return true
    }
}

extension Checker.Declaration {
    var isChecked: Bool {
        return true
    }
}

extension Checker.Function {
    var isChecked: Bool {
        return true
    }
}

extension Checker.Identifier {
    var isChecked: Bool {
        return true
    }
}

extension Checker.Infix {
    var isChecked: Bool {
        return true
    }
}

extension Checker.Paren {
    var isChecked: Bool {
        return true
    }
}

extension Checker.PolymorphicFunction {
    var isChecked: Bool {
        return true
    }
}

extension Checker.Prefix {
    var isChecked: Bool {
        return true
    }
}


extension Type {

    var asBuiltin: Type.Builtin {
        get {
            assert(kind == Builtin.typeKind)
            return value.baseAddress!.assumingMemoryBound(to: Builtin.self).pointee
        }
        set {
            kind = Builtin.typeKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<Builtin>.size)
            value.baseAddress!.assumingMemoryBound(to: Builtin.self).initialize(to: newValue)
        }
    }

    var asFunction: Type.Function {
        get {
            assert(kind == Function.typeKind)
            return value.baseAddress!.assumingMemoryBound(to: Function.self).pointee
        }
        set {
            kind = Function.typeKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<Function>.size)
            value.baseAddress!.assumingMemoryBound(to: Function.self).initialize(to: newValue)
        }
    }

    var asMetatype: Type.Metatype {
        get {
            assert(kind == Metatype.typeKind)
            return value.baseAddress!.assumingMemoryBound(to: Metatype.self).pointee
        }
        set {
            kind = Metatype.typeKind
            value.deallocate()
            value = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<Metatype>.size)
            value.baseAddress!.assumingMemoryBound(to: Metatype.self).initialize(to: newValue)
        }
    }
}
