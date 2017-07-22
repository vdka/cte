// Generated using Sourcery 0.7.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

extension AstValue {
    func cmp(rhs: AstValue) -> Bool {
        switch (self, rhs) {
        case (let a as AstNode.Access, let b as AstNode.Access):
            if a.aggregate != b.aggregate { return false}
            if a.member != b.member { return false}
            return true

        case (let a as AstNode.Assign, let b as AstNode.Assign):
            if a.lvalues != b.lvalues { return false}
            if a.rvalues != b.rvalues { return false}
            return true

        case (let a as AstNode.Block, let b as AstNode.Block):
            if a.stmts != b.stmts { return false}
            if a.isForeign != b.isForeign { return false}
            if a.isFunction != b.isFunction { return false}
            return true

        case (let a as AstNode.Break, let b as AstNode.Break):
            if a.label != b.label { return false}
            return true

        case (let a as AstNode.Call, let b as AstNode.Call):
            if a.callee != b.callee { return false}
            if a.arguments != b.arguments { return false}
            return true

        case (let a as AstNode.Case, let b as AstNode.Case):
            if a.condition != b.condition { return false}
            if a.block != b.block { return false}
            return true

        case (let a as AstNode.Comment, let b as AstNode.Comment):
            if a.comment != b.comment { return false}
            return true

        case (let a as AstNode.CompileTime, let b as AstNode.CompileTime):
            if a.stmt != b.stmt { return false}
            return true

        case (let a as AstNode.CompositeLiteral, let b as AstNode.CompositeLiteral):
            if a.typeNode != b.typeNode { return false}
            if a.elements != b.elements { return false}
            return true

        case (let a as AstNode.CompositeLiteralField, let b as AstNode.CompositeLiteralField):
            if a.identifier != b.identifier { return false}
            if a.value != b.value { return false}
            return true

        case (let a as AstNode.Continue, let b as AstNode.Continue):
            if a.label != b.label { return false}
            return true

        case (let a as AstNode.Declaration, let b as AstNode.Declaration):
            if a.names != b.names { return false}
            if a.type != b.type { return false}
            if a.values != b.values { return false}
            if a.linkName != b.linkName { return false}
            if a.flags != b.flags { return false}
            return true

        case (let a as AstNode.Empty, let b as AstNode.Empty):
            return true

        case (let a as AstNode.Fallthrough, let b as AstNode.Fallthrough):
            return true

        case (let a as AstNode.FloatLiteral, let b as AstNode.FloatLiteral):
            if a.value != b.value { return false}
            return true

        case (let a as AstNode.For, let b as AstNode.For):
            if a.label != b.label { return false}
            if a.initializer != b.initializer { return false}
            if a.condition != b.condition { return false}
            if a.step != b.step { return false}
            if a.body != b.body { return false}
            return true

        case (let a as AstNode.Foreign, let b as AstNode.Foreign):
            if a.library != b.library { return false}
            if a.stmt != b.stmt { return false}
            return true

        case (let a as AstNode.Function, let b as AstNode.Function):
            if a.parameters != b.parameters { return false}
            if a.returnTypes != b.returnTypes { return false}
            if a.body != b.body { return false}
            if a.flags != b.flags { return false}
            return true

        case (let a as AstNode.FunctionType, let b as AstNode.FunctionType):
            if a.parameters != b.parameters { return false}
            if a.returnTypes != b.returnTypes { return false}
            if a.flags != b.flags { return false}
            return true

        case (let a as AstNode.Identifier, let b as AstNode.Identifier):
            if a.name != b.name { return false}
            return true

        case (let a as AstNode.If, let b as AstNode.If):
            if a.condition != b.condition { return false}
            if a.thenStmt != b.thenStmt { return false}
            if a.elseStmt != b.elseStmt { return false}
            return true

        case (let a as AstNode.Import, let b as AstNode.Import):
            if a.path != b.path { return false}
            if a.symbol != b.symbol { return false}
            if a.includeSymbolsInParentScope != b.includeSymbolsInParentScope { return false}
            if a.file != b.file { return false}
            return true

        case (let a as AstNode.Infix, let b as AstNode.Infix):
            if a.token != b.token { return false}
            if a.lhs != b.lhs { return false}
            if a.rhs != b.rhs { return false}
            return true

        case (let a as AstNode.IntegerLiteral, let b as AstNode.IntegerLiteral):
            if a.value != b.value { return false}
            return true

        case (let a as AstNode.Invalid, let b as AstNode.Invalid):
            return true

        case (let a as AstNode.Library, let b as AstNode.Library):
            if a.path != b.path { return false}
            if a.symbol != b.symbol { return false}
            return true

        case (let a as AstNode.List, let b as AstNode.List):
            if a.values != b.values { return false}
            return true

        case (let a as AstNode.Parameter, let b as AstNode.Parameter):
            if a.name != b.name { return false}
            if a.type != b.type { return false}
            return true

        case (let a as AstNode.Paren, let b as AstNode.Paren):
            if a.expr != b.expr { return false}
            return true

        case (let a as AstNode.PointerType, let b as AstNode.PointerType):
            if a.pointee != b.pointee { return false}
            return true

        case (let a as AstNode.Prefix, let b as AstNode.Prefix):
            if a.token != b.token { return false}
            if a.expr != b.expr { return false}
            return true

        case (let a as AstNode.Return, let b as AstNode.Return):
            if a.values != b.values { return false}
            return true

        case (let a as AstNode.StringLiteral, let b as AstNode.StringLiteral):
            if a.value != b.value { return false}
            return true

        case (let a as AstNode.StructType, let b as AstNode.StructType):
            if a.declarations != b.declarations { return false}
            return true

        case (let a as AstNode.Switch, let b as AstNode.Switch):
            if a.label != b.label { return false}
            if a.subject != b.subject { return false}
            if a.cases != b.cases { return false}
            return true

        case (let a as AstNode.Variadic, let b as AstNode.Variadic):
            if a.type != b.type { return false}
            if a.cCompatible != b.cCompatible { return false}
            return true

        default: return false
        }
    }
}
