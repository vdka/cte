
struct Checker {
    var nodes: [AstNode]

    var currentScope: Scope = Scope(parent: Scope.global)
    var currentExpectedReturnType: Type? = nil

    init(nodes: [AstNode]) {
        self.nodes = nodes
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

            node.asCheckedDeclaration = Declaration(identifier: decl.identifier, type: decl.type,
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

            node.asCheckedBlock = Block(stmts: block.stmts, scope: currentScope)

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
            node.asCheckedIdentifier = Identifier(name: ident, entity: entity)
            return entity.type!

        case .litString:
            return Type.string

        case .litNumber:
            return Type.number

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

                node.asCheckedPolymorphicFunction = PolymorphicFunction(
                    parameters: fn.parameters, returnType: fn.returnType, body: fn.body,
                    type: type, specializations: [])
            } else {

                node.asCheckedFunction = Function(
                    parameters: fn.parameters, returnType: fn.returnType, body: fn.body,
                    scope: currentScope, type: type)
            }

            return type

        case .paren:
            let paren = node.asParen
            let type = checkExpr(node: paren.expr)
            node.asCheckedParen = Paren(expr: paren.expr, type: type)
            return type

        case .prefix:
            let prefix = node.asPrefix
            let type = checkExpr(node: prefix.expr)
            guard type == Type.number else {
                reportError("Prefix operator '\(prefix.kind)', is invalid on type '\(type)'", at: prefix.expr)
                return Type.invalid
            }
            node.asCheckedPrefix = Prefix(kind: prefix.kind, expr: prefix.expr, type: type)
            return type

        case .infix:
            let infix = node.asInfix
            let lhsType = checkExpr(node: infix.lhs)
            let rhsType = checkExpr(node: infix.rhs)
            guard lhsType == Type.number, lhsType == rhsType else {
                reportError("Infix operator '\(infix.kind)', is only valid on 'number' types", at: node)
                return Type.invalid
            }

            var type: Type
            switch infix.kind {
            case .lt, .lte, .gt, .gte:
                type = Type.bool

            case .plus, .minus:
                type = Type.number

            default:
                fatalError()
            }

            node.asCheckedInfix = Infix(kind: infix.kind, lhs: infix.lhs, rhs: infix.rhs, type: type)
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
                node.asCheckedCall = Call(callee: call.callee, arguments: call.arguments, isSpecialized: false, type: resultType)

                return resultType
            }

        default:
            fatalError()
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

            // check the declaration as usual.
            check(node: param)

            let entity = currentScope.members.last!

            if entity.flags.contains(.ct) {

                // Inject the type we are specializing to.
                entity.type = specializedTypeIterator.next()!
            }

            params.append(entity)
        }

        for (arg, expected) in zip(call.arguments, params) {

            let argType = checkExpr(node: arg)

            guard argType == expected.type! else {
                reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expected.type!)'", at: arg)
                continue
            }
        }

        var returnType = checkExpr(node: fn.returnType)
        returnType = lowerFromMetatype(returnType, atNode: fn.returnType)

        let prevExpectedReturnType = currentExpectedReturnType
        currentExpectedReturnType = returnType
        defer {
            currentExpectedReturnType = prevExpectedReturnType
        }

        check(node: fn.body)

        let stripped = Type.Function(node: fnNode, params: params.filter({ !$0.flags.contains(.ct) }), returnType: returnType, needsSpecialization: false)
        let strippedType = Type(value: stripped, entity: Entity.anonymous)

        fnNode.asCheckedPolymorphicFunction.specializations.append((specializations, strippedType: strippedType))

        callNode.asCheckedCall = Call(callee: call.callee, arguments: call.arguments, isSpecialized: true, type: returnType)

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


// The memory layout must be an ordered superset of Unchecked for all of these.
extension Checker {

    struct Identifier: AstNodeValue {
        static let astKind = AstKind.identifier

        let name: String
        let entity: Entity
    }

    struct Function: AstNodeValue {
        static let astKind = AstKind.function

        let parameters: [AstNode]
        let returnType: AstNode
        let body: AstNode

        /// The scope the parameters occur within
        let scope: Scope
        let type: Type
    }

    struct PolymorphicFunction: AstNodeValue {
        static let astKind = AstKind.polymorphicFunction

        let parameters: [AstNode]
        let returnType: AstNode
        let body: AstNode

        let type: Type

        var specializations: [(specializedTypes: [Type], strippedType: Type)]
    }

    struct Declaration: AstNodeValue {
        static let astKind = AstKind.declaration

        let identifier: AstNode
        let type: AstNode?
        let value: AstNode
        let isCompileTime: Bool

        let entity: Entity
    }

    struct Paren: AstNodeValue {
        static let astKind = AstKind.paren

        let expr: AstNode
        let type: Type
    }

    struct Prefix: AstNodeValue {
        static let astKind = AstKind.prefix

        let kind: Token.Kind
        let expr: AstNode

        let type: Type
    }

    struct Infix: AstNodeValue {
        static let astKind = AstKind.infix

        let kind: Token.Kind
        let lhs: AstNode
        let rhs: AstNode
        let type: Type
    }

    struct Call: AstNodeValue {
        static let astKind = AstKind.call

        let callee: AstNode
        let arguments: [AstNode]

        let isSpecialized: Bool
        let type: Type
    }

    struct Block: AstNodeValue {
        static let astKind = AstKind.block

        let stmts: [AstNode]
        let scope: Scope
    }
}
