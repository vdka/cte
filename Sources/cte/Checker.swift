
import LLVM

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
                if !(decl.isCompileTime && expectedType == Type.type) {
//                if !(decl.isCompileTime && expectedType!.kind == .metatype && expectedType!.asMetatype.instanceType == Type.type) {
                    expectedType = lowerFromMetatype(expectedType!, atNode: dType)
//                }
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
            let lit = node.asFloatLiteral
            let type = Type.f64
            node.value = FloatLiteral(value: lit.value, type: type)
            return type

        case .litInteger:
            let lit = node.asIntegerLiteral
            let type = Type.i64
            node.value = IntegerLiteral(value: lit.value, type: type)
            return type

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
                    scope: currentScope, type: type, isSpecialization: false)
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

            let resultType: Type
            let op: OpCode.Binary

            // Used to communicate any implicit casts to perform for this operation
            var (lCast, rCast): (OpCode.Cast?, OpCode.Cast?) = (nil, nil)

            // Handle Extending or Truncating
            if lhsType == rhsType {
                resultType = lhsType
            } else if lhsType.isInteger && rhsType.isFloatingPoint {
                lCast = lhsType.isSignedInteger ? .siToFP : .uiToFP
                resultType = rhsType
            } else if rhsType.isInteger && lhsType.isFloatingPoint {
                rCast = rhsType.isSignedInteger ? .siToFP : .uiToFP
                resultType = rhsType
            } else if (lhsType.isSignedInteger && rhsType.isUnsignedInteger) || (rhsType.isSignedInteger && lhsType.isUnsignedInteger) {
                reportError("Implicit conversion between signed and unsigned integers in operator is disallowed", at: node)
                return Type.invalid
            } else if lhsType.isInteger && rhsType.isInteger { // select the largest
                if lhsType.width! < rhsType.width! {
                    resultType = rhsType
                    lCast = lhsType.isSignedInteger ? OpCode.Cast.sext : OpCode.Cast.zext
                } else {
                    resultType = lhsType
                    rCast = rhsType.isSignedInteger ? OpCode.Cast.sext : OpCode.Cast.zext
                }
            } else if lhsType.isFloatingPoint && rhsType.isFloatingPoint {
                if lhsType.width! < rhsType.width! {
                    resultType = rhsType
                    lCast = .fpext
                } else {
                    resultType = lhsType
                    rCast = .fpext
                }
            } else {
                reportError("Operator '\(infix.kind) is not valid between '\(lhsType)' and '\(rhsType)' types", at: node)
                return Type.invalid
            }

            assert((lhsType == rhsType) || lCast != nil || rCast != nil, "We must have 2 same types or a way to acheive them by here")

            let isIntegerOp = lhsType.isInteger || rhsType.isInteger

            var type: Type
            switch infix.kind {
            case .lt, .lte, .gt, .gte:
                guard lhsType.isNumber && rhsType.isNumber else {
                    reportError("Cannot compare '\(lhsType)' and '\(rhsType)' comparison is only valid on 'number' types", at: node)
                    return Type.invalid
                }
                op = isIntegerOp ? .icmp : .fcmp
                type = Type.bool

            case .plus:
                op = isIntegerOp ? .add : .fadd
                type = resultType

            case .minus:
                op = isIntegerOp ? .sub : .fsub
                type = resultType

            default:
                fatalError()
            }

            node.value = Infix(kind: infix.kind, lhs: infix.lhs, rhs: infix.rhs, type: type, op: op, lhsCast: lCast, rhsCast: rCast)
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
                node.value = Call(callee: call.callee, arguments: call.arguments, specialization: nil, type: resultType)

                return resultType
            }

        default:
            reportError("Cannot convert '\(node)' to an Expression", at: node)
            return Type.invalid
        }
    }

    mutating func checkPolymorphicCall(callNode: AstNode, calleeType: Type) -> Type {
        let call = callNode.asCall
        var fnNode = calleeType.asFunction.node
        var fn = fnNode.asCheckedPolymorphicFunction

        var specializations: [Type] = []
        for (arg, expected) in zip(call.arguments, calleeType.asFunction.params).filter({ $0.1.flags.contains(.ct) }) {

            let argType = checkExpr(node: arg)

            guard argType == expected.type! || argType.isMetatype && expected.type == Type.type else {
                reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expected.type!)'", at: arg)
                return Type.invalid // Don't even bother trying to recover from specialized function checking
            }

            specializations.append(argType)
        }

        // If there is already a matching specialization no need to recheck
        if let specialization = fn.specializations.firstMatching(specializations) {

            let runtimeArguments = zip(call.arguments, calleeType.asFunction.params)
                .filter({ !$0.1.flags.contains(.ct) })
                .map({ $0.0 })
            // check runtime arguments
            for (arg, expected) in zip(runtimeArguments, specialization.strippedType.asFunction.params) {
                let argType = checkExpr(node: arg)

                guard argType == expected.type! else {
                    reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expected.type!)'", at: arg)
                    continue
                }
            }

            let returnType = specialization.strippedType.asFunction.returnType

            var strippedArguments = call.arguments
            for index in specialization.specializationIndices.reversed() {
                // remove arguments no longer needed at runtime
                strippedArguments.remove(at: index)
            }
            callNode.value = Call(callee: call.callee, arguments: strippedArguments, specialization: specialization, type: returnType)
            return returnType
        }

        let originalFnNode = fnNode

        fnNode = fnNode.copy()
        fn = fnNode.asCheckedPolymorphicFunction

        let prevScope = currentScope
        currentScope = Scope(parent: currentScope)
        defer {
            currentScope = prevScope
        }

        var specializedTypeIterator = specializations.makeIterator()
        var params: [Entity] = []
        var specializationIndices: [Int] = []
        for (index, param) in fn.parameters.enumerated() {
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
                specializationIndices.append(index)
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

        let strippedFunction = Type.Function(node: fnNode, params: params.filter({ !$0.flags.contains(.ct) }),
                                             returnType: returnType, needsSpecialization: false)
        let strippedType = Type(value: strippedFunction, entity: Entity.anonymous)

        var strippedParameters = fn.parameters
        for index in specializationIndices.reversed() {
            strippedParameters.remove(at: index)
        }

        fnNode.value = Function(
            parameters: strippedParameters, returnType: fn.returnType, body: fn.body,
            scope: currentScope, type: strippedType, isSpecialization: true)

        let specialization = FunctionSpecialization(specializationIndices: specializationIndices, specializedTypes: specializations,
                                                    strippedType: strippedType, fnNode: fnNode)

        // write the added specialization back to the original function declaration
        var originalPolymorphicFunction = originalFnNode.asCheckedPolymorphicFunction
        originalPolymorphicFunction.specializations.append(specialization)
        originalFnNode.value = originalPolymorphicFunction

        var strippedArguments = call.arguments
        for index in specializationIndices.reversed() {
            // remove arguments no longer needed at runtime
            strippedArguments.remove(at: index)
        }

        callNode.value = Call(callee: call.callee, arguments: strippedArguments, specialization: specialization, type: returnType)

        return returnType
    }

    func lowerFromMetatype(_ type: Type, atNode node: AstNode) -> Type {

        if type.kind == .metatype {
            return Type.lowerFromMetatype(type)
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

extension AstNode {

    /// - Warning: Will assert if the AstValue is not a Checked Expression
    var exprType: Type {
        assert(self.value is CheckedExpression)

        return (self.value as! CheckedExpression).type
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
        let isSpecialization: Bool
    }

    struct PolymorphicFunction: CheckedExpression, CheckedAstValue {
        static let astKind = AstKind.polymorphicFunction

        typealias UncheckedValue = AstNode.Function

        let parameters: [AstNode]
        let returnType: AstNode
        let body: AstNode

        let type: Type

        var specializations: [FunctionSpecialization] = []
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

        let op: OpCode.Binary
        let lhsCast: OpCode.Cast?
        let rhsCast: OpCode.Cast?
    }

    struct Call: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.Call

        let callee: AstNode
        let arguments: [AstNode]

        let specialization: FunctionSpecialization?
        let type: Type
    }

    struct Block: CheckedAstValue {
        typealias UncheckedValue = AstNode.Block

        let stmts: [AstNode]
        let scope: Scope
    }
}

class FunctionSpecialization {
    let specializationIndices: [Int]
    let specializedTypes: [Type]
    let strippedType: Type
    let fnNode: AstNode
    var llvm: Function?

    init(specializationIndices: [Int], specializedTypes: [Type], strippedType: Type, fnNode: AstNode, llvm: Function? = nil) {
        assert(fnNode.value is Checker.Function)
        self.specializationIndices = specializationIndices
        self.specializedTypes = specializedTypes
        self.strippedType = strippedType
        self.fnNode = fnNode
        self.llvm = llvm
    }
}

extension Array where Element == FunctionSpecialization {

    func firstMatching(_ specializationTypes: [Type]) -> FunctionSpecialization? {

        for specialization in self {

            if zip(specialization.specializedTypes, specializationTypes).reduce(true, { $0 && $1.0 === $1.1 }) {
                return specialization
            }
        }
        return nil
    }
}
