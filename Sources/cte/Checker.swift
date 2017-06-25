
struct Checker {
    var nodes: [AstNode]

    var currentScope: Scope = Scope(parent: Scope.global)
    var currentExpectedReturnType: Type? = nil

    init(nodes: [AstNode]) {
        self.nodes = nodes

        // Ensure builtins are declared
        _ = BuiltinType.void
        _ = BuiltinType.type
        _ = BuiltinType.bool
        _ = BuiltinType.string
        _ = BuiltinType.f64
        _ = BuiltinType.u8
    }
}


extension Checker {

    mutating func check() {

        for node in nodes {
            check(node: node)
        }
    }

    mutating func check(node: AstNode) {

        switch node.kind {
        case .empty:
            return

        case .identifier, .call, .paren, .prefix, .infix:
            let type = checkExpr(node: node)
            reportError("Expression of type '\(type)' is unused", at: node)

        case .declaration:
            let decl = node.asDeclaration
            var expectedType: Type?

            if let dType = decl.type {
                expectedType = checkExpr(node: dType)

                // Really long way to check if the decl is something like `$T: type`
                if !(decl.isCompileTime && expectedType!.kind == .metatype && expectedType!.asMetatype.instanceType == Type.type) {
                    expectedType = lowerFromMetatype(expectedType!, atNode: dType)
                }
            }

            var type = (decl.value == .empty) ? expectedType! : checkExpr(node: decl.value)

            if let expectedType = expectedType, type != expectedType {
                reportError("Cannot convert value of type '\(type)' to specified type '\(expectedType)'", at: node)
                type = Type.invalid
            }

            assert(decl.identifier.kind == .identifier)
            let identifierToken = decl.isCompileTime ? decl.identifier.tokens.last! : decl.identifier.tokens.first!
            let entity = Entity(ident: identifierToken, type: type)

            if decl.isCompileTime {
                entity.flags.insert(.ct)
            }

            if type == Type.type {
                entity.flags.insert(.type)
            }

            currentScope.insert(entity)

            node.value = Declaration(identifier: decl.identifier, type: decl.type,
                                                    value: decl.value, isCompileTime: decl.isCompileTime,
                                                    entity: entity)

        case .block:
            let block = node.asBlock

            let prevScope = currentScope
            currentScope = Scope(parent: currentScope)
            defer {
                currentScope = prevScope
            }
            for node in block.stmts {
                check(node: node)
            }

            node.value = Block(stmts: block.stmts, scope: currentScope)

        case .if:
            let iff = node.asIf

            let condType = checkExpr(node: iff.condition)
            if condType != Type.bool {
                reportError("Cannot convert type '\(iff.condition)' to expected type 'bool'", at: iff.condition)
            }

            check(node: iff.thenStmt)

            if let elsé = iff.elseStmt {
                check(node: elsé)
            }

        case .return:
            let ret = node.asReturn
            let type = checkExpr(node: ret.value)

            if type != currentExpectedReturnType! {
                reportError("Cannot convert type '\(type)' to expected type '\(currentExpectedReturnType!)'", at: ret.value)
            }

        default:
            fatalError()
        }
    }

    mutating func checkExpr(node: AstNode) -> Type {

        switch node.kind {
        case .identifier:
            let ident = node.asIdentifier.name
            guard let entity = self.currentScope.lookup(ident) else {
                reportError("Use of undefined identifier '\(ident)'", at: node)
                return Type.invalid
            }
            node.value = Identifier(name: ident, entity: entity)
            return entity.type!

        case .litString:
            return Type.string

        case .litFloat:
            return Type.f64

        case .litInteger:
            return Type.i64

        case .function:
            let fn = node.asFunction

            let prevScope = currentScope
            currentScope = Scope(parent: currentScope)
            defer {
                currentScope = prevScope
            }

            var needsSpecialization = false
            var params: [Entity] = []
            for param in fn.parameters {
                assert(param.kind == .declaration)

                check(node: param)

                let entity = currentScope.members.last!

                if entity.flags.contains(.ct) {
                    needsSpecialization = true
                }

                params.append(entity)
            }

            var returnType = checkExpr(node: fn.returnType)
            returnType = lowerFromMetatype(returnType, atNode: fn.returnType)

            let prevExpectedReturnType = currentExpectedReturnType
            currentExpectedReturnType = returnType
            defer {
                currentExpectedReturnType = prevExpectedReturnType
            }

            if !needsSpecialization { // polymorphic functions are checked when called
                check(node: fn.body)
            }

            let functionType = Type.Function(node: node, params: params, returnType: returnType, needsSpecialization: needsSpecialization)

            let type = Type(value: functionType, entity: Entity.anonymous)

            if needsSpecialization {

                node.value = PolymorphicFunction(parameters: fn.parameters, returnType: fn.returnType, body: fn.body, type: type, specializations: [])
            } else {

                node.value = Function(
                    parameters: fn.parameters, returnType: fn.returnType, body: fn.body,
                    scope: currentScope, type: type)
            }

            return type

        case .pointerType:
            let pointerType = node.asPointerType
            let pointeeType = checkExpr(node: pointerType.pointee)

            let instanceType = Type.makePointer(to: pointeeType)
            let type = Type.makeMetatype(instanceType)
            node.value = PointerType(pointee: pointerType.pointee, type: type)
            return type

        case .paren:
            let paren = node.asParen
            let type = checkExpr(node: paren.expr)
            node.value = Paren(expr: paren.expr, type: type)
            return type

        // FIXME:
        case .prefix:
            let prefix = node.asPrefix
            var type = checkExpr(node: prefix.expr)

            switch prefix.kind {
            case .plus, .minus:
                guard type == Type.f64 else {
                    reportError("Prefix operator '\(prefix.kind)' is only valid on signed numeric types", at: prefix.expr)
                    return Type.invalid
                }

            case .lt:
                guard type.kind == .pointer else {
                    reportError("Cannot dereference '\(prefix.expr)'", at: node)
                    return Type.invalid
                }

                type = type.asPointer.pointeeType

            case .ampersand:
                guard prefix.expr.isLvalue else {
                    reportError("Cannot take the address of a non lvalue", at: node)
                    return Type.invalid
                }
                type = Type.makePointer(to: type)

            default:
                reportError("Prefix operator '\(prefix.kind)', is invalid on type '\(type)'", at: prefix.expr)
                return Type.invalid
            }
            node.value = Prefix(kind: prefix.kind, expr: prefix.expr, type: type)
            return type

        // FIXME:
        case .infix:
            let infix = node.asInfix
            let lhsType = checkExpr(node: infix.lhs)
            let rhsType = checkExpr(node: infix.rhs)
            guard lhsType == Type.f64 || rhsType == Type.f32, lhsType == rhsType else {
                reportError("Infix operator '\(infix.kind)', is only valid on 'number' types", at: node)
                return Type.invalid
            }

            var type: Type
            switch infix.kind {
            case .lt, .lte, .gt, .gte:
                type = Type.bool

            case .plus, .minus:
                type = Type.f64

            default:
                fatalError()
            }

            node.value = Infix(kind: infix.kind, lhs: infix.lhs, rhs: infix.rhs, type: type)
            return type

        case .call:
            let call = node.asCall
            let calleeType = checkExpr(node: call.callee)
            guard case .function = calleeType.kind else {
                reportError("Cannot call value of non-function type '\(calleeType)'", at: node)
                return Type.invalid
            }

            if calleeType.asFunction.needsSpecialization {

                return checkPolymorphicCall(callNode: node, calleeType: calleeType)
            } else {

                for (arg, expected) in zip(call.arguments, calleeType.asFunction.params) {
                    assert(!expected.flags.contains(.ct), "functions with ct params should be marked as needing specialization")

                    let argType = checkExpr(node: arg)

                    guard argType == expected.type! else {
                        reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expected)'", at: arg)
                        continue
                    }
                }

                let resultType = calleeType.asFunction.returnType
                node.value = Call(callee: call.callee, arguments: call.arguments, isSpecialized: false, type: resultType)

                return resultType
            }

        default:
            reportError("Cannot convert '\(node)' to an Expression", at: node)
            return Type.invalid
        }
    }

    mutating func checkPolymorphicCall(callNode: AstNode, calleeType: Type) -> Type {
        let call = callNode.asCall
        let fnNode = calleeType.asFunction.node
        let fn = fnNode.asCheckedPolymorphicFunction

        var specializations: [Type] = []
        for (arg, expected) in zip(call.arguments, calleeType.asFunction.params).filter({ $0.1.flags.contains(.ct) }) {

            let argType = checkExpr(node: arg)

            guard argType == expected.type! else {
                reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expected)'", at: arg)
                return Type.invalid // Don't even bother trying to recover from specialized function checking
            }

            specializations.append(argType)
        }

        let prevScope = currentScope
        currentScope = Scope(parent: currentScope)
        defer {
            currentScope = prevScope
        }

        var specializedTypeIterator = specializations.makeIterator()
        var params: [Entity] = []
        for param in fn.parameters {
            assert(param.kind == .declaration)

            let decl = param.asCheckedDeclaration
            // Changed the param node value back to being unchecked
            param.value = AstNode.Declaration(identifier: decl.identifier, type: decl.type, value: decl.value, isCompileTime: decl.isCompileTime)

            // check the declaration as usual.
            check(node: param)

            let entity = currentScope.members.last!

            if entity.flags.contains(.ct) {

                // Inject the type we are specializing to.
                entity.type = specializedTypeIterator.next()!
            }

            params.append(entity)
        }

        var returnType = checkExpr(node: fn.returnType)
        returnType = lowerFromMetatype(returnType, atNode: fn.returnType)

        let prevExpectedReturnType = currentExpectedReturnType
        currentExpectedReturnType = returnType
        defer {
            currentExpectedReturnType = prevExpectedReturnType
        }

        // Return to the calling scope to check the validity of the argument expressions
        // Once done return to the function scope to check the body
        let fnScope = currentScope
        currentScope = prevScope
        for (arg, expected) in zip(call.arguments, params) {

            let argType = checkExpr(node: arg)

            guard argType == expected.type! else {
                reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expected.type!)'", at: arg)
                continue
            }
        }
        currentScope = fnScope

        check(node: fn.body)

        let stripped = Type.Function(node: fnNode, params: params.filter({ !$0.flags.contains(.ct) }), returnType: returnType, needsSpecialization: false)
        let strippedType = Type(value: stripped, entity: Entity.anonymous)

        // If there is already a matching specialization no need to duplicate it
        if !fn.specializations.contains(where: { $0.specializedTypes == specializations }) {

            var pmFn = fnNode.asCheckedPolymorphicFunction
            pmFn.specializations.append((specializations, strippedType: strippedType))
            fnNode.value = pmFn
        }

        callNode.value = Call(callee: call.callee, arguments: call.arguments, isSpecialized: true, type: returnType)

        return returnType
    }

    func lowerFromMetatype(_ type: Type, atNode node: AstNode) -> Type {

        if type.kind == .metatype {
            return type.asMetatype.instanceType
        }

        reportError("'\(type)' cannot be used as a type", at: node)
        return Type.invalid
    }
}

extension AstNode {

    var isStmt: Bool {
        switch self.kind {
        case .if, .return, .block, .declaration, .empty:
            return true

        default:
            return false
        }
    }

    var isLvalue: Bool {

        switch self.kind {
        case _ where isStmt:
            return false

        case  .prefix, .infix, .litFloat, .litString, .call, .function, .polymorphicFunction, .pointerType:
            return false

        case .paren:
            return asParen.expr.isLvalue

        case .identifier:
            return true

        default:
            return false
        }
    }

    var isRvalue: Bool {

        switch self.kind {
        case _ where isStmt:
            return false

        case .identifier, .call, .function, .polymorphicFunction, .prefix, .infix, .paren, .litFloat, .litString, .pointerType:
            return true

        default:
            return false
        }
    }
}


// MARK: Checked AstValue's

protocol CheckedAstValue: AstValue {
    associatedtype UncheckedValue: AstValue

    func downcast() -> UncheckedValue
}

protocol CheckedExpression {
    var type: Type { get }
}

extension CheckedAstValue {
    static var astKind: AstKind {
        return UncheckedValue.astKind
    }

    func downcast() -> UncheckedValue {

        var copy = self
        return withUnsafePointer(to: &copy) {
            return $0.withMemoryRebound(to: UncheckedValue.self, capacity: 1, { $0 }).pointee
        }
    }
}

// The memory layout must be an ordered superset of Unchecked for all of these.
extension Checker {

    struct Identifier: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.Identifier

        let name: String
        let entity: Entity

        var type: Type {
            return entity.type!
        }
    }

    struct StringLiteral: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.StringLiteral

        let value: String

        let type: Type
    }

    struct FloatLiteral: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.FloatLiteral

        let value: Double

        let type: Type
    }

    struct IntegerLiteral: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.IntegerLiteral

        let value: UInt64

        let type: Type
    }

    struct Function: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.Function

        let parameters: [AstNode]
        let returnType: AstNode
        let body: AstNode

        /// The scope the parameters occur within
        let scope: Scope
        let type: Type
    }

    struct PolymorphicFunction: CheckedExpression, CheckedAstValue {
        static let astKind = AstKind.polymorphicFunction

        typealias UncheckedValue = AstNode.Function

        let parameters: [AstNode]
        let returnType: AstNode
        let body: AstNode

        let type: Type

        var specializations: [(specializedTypes: [Type], strippedType: Type)] = []
    }

    struct PointerType: CheckedAstValue {
        typealias UncheckedValue = AstNode.PointerType

        let pointee: AstNode
        let type: Type
    }

    struct Declaration: CheckedAstValue {
        typealias UncheckedValue = AstNode.Declaration

        let identifier: AstNode
        let type: AstNode?
        let value: AstNode
        let isCompileTime: Bool

        let entity: Entity
    }

    struct Paren: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.Paren

        let expr: AstNode
        let type: Type
    }

    struct Prefix: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.Prefix

        let kind: Token.Kind
        let expr: AstNode

        let type: Type
    }

    struct Infix: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.Infix

        let kind: Token.Kind
        let lhs: AstNode
        let rhs: AstNode
        let type: Type
    }

    struct Call: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.Call

        let callee: AstNode
        let arguments: [AstNode]

        let isSpecialized: Bool
        let type: Type
    }

    struct Block: CheckedAstValue {
        typealias UncheckedValue = AstNode.Block

        let stmts: [AstNode]
        let scope: Scope
    }
}
