
import LLVM

struct Checker {
    var file: SourceFile

    var currentScope: Scope
    var currentExpectedReturnType: Type? = nil
    var currentSpecializationCall: AstNode? = nil

    init(file: SourceFile) {
        self.file = file
        self.currentScope = Scope(parent: Scope.global, file: file)
    }
}

extension Checker {

    mutating func check() {

        for node in file.nodes {
            check(node: node)
        }
    }

    mutating func check(node: AstNode) {

        switch node.kind {
        case .empty, .comment:
            return

        case .identifier, .call, .paren, .prefix, .infix:
            let type = checkExpr(node: node)
            if !(node.isDiscardable || type.isVoid) {
                reportError("Expression of type '\(type)' is unused", at: node)
            }

        case .compileTime:
            let stmt = node.asCompileTime.stmt
            switch stmt.kind {
            case .declaration:
                var decl = stmt.asUncheckedDeclaration
                decl.flags.insert(.compileTime)
                node.value = decl

            default:
                reportError("'$' is not valid on '\(stmt)'", at: node)
            }

        case .declaration:
            let decl = node.asDeclaration
            var expectedType: Type?

            if let dType = decl.type {
                expectedType = checkExpr(node: dType)

                // Check if the declaration is a polymorphic type declaration
                if !(decl.isCompileTime && expectedType == Type.type) {
                    expectedType = lowerFromMetatype(expectedType!, atNode: dType)
                }
            }

            var type = (decl.value == .empty) ? expectedType! : checkExpr(node: decl.value, desiredType: expectedType)

            if decl.rvalueIsCall {
                type = type.asTuple.types[0]
            }

            if decl.isForeign, decl.isCompileTime {
                guard type.isMetatype else {
                    reportError("Expected 'type' as rvalue for foreign symbol, got '\(type)'", at: decl.value)
                    type = Type.invalid
                    return
                }
                type = Type.lowerFromMetatype(type)

                if decl.value.kind == .functionType {
                    type = type.asPointer.pointeeType
                }
            }

            if let expectedType = expectedType, type != expectedType &&
                (Type.makePointer(to: type) != expectedType && type.isFunction && expectedType.isFunctionPointer) {
                reportError("Cannot convert value of type '\(type)' to specified type '\(expectedType)'", at: node)
                type = Type.invalid
            }

            assert(decl.identifier.kind == .identifier)
            let identifierToken = decl.isCompileTime ? decl.identifier.tokens.last! : decl.identifier.tokens.first!
            let entity = Entity(ident: identifierToken, type: type)

            if decl.isCompileTime {
                entity.flags.insert(.ct)
            }

            if decl.isForeign {
                entity.flags.insert(.foreign)
            }

            if type == Type.type {
                entity.flags.insert(.type)
            }

            currentScope.insert(entity)

            node.value = Declaration(identifier: decl.identifier, type: decl.type, value: decl.value,
                                     linkName: decl.linkName, flags: decl.flags, entity: entity)

        case .assign:
            let assign = node.asAssign

            var lvalueTypes: [Type] = []
            for lvalue in assign.lvalues {
                let type = checkExpr(node: lvalue)
                lvalueTypes.append(type)

                guard lvalue.isLvalue else {
                    reportError("Cannot assign to '\(lvalue)'", at: lvalue)
                    continue
                }
            }
            var rvalueTypes: [Type] = []
            if assign.rvalueIsCall, let call = assign.rvalues.first {
                rvalueTypes = checkExpr(node: call).asTuple.types
            } else if assign.lvalues.count != assign.rvalues.count {
                reportError("Assignment count mismatch \(assign.lvalues.count) = \(assign.rvalues.count)", at: node)
            } else {
                var rvalueTypes: [Type] = []
                for (expectedType, rvalue) in zip(lvalueTypes, assign.rvalues) {
                    let type = checkExpr(node: rvalue, desiredType: expectedType)
                    rvalueTypes.append(type)

                    guard rvalue.isRvalue || type == .invalid else {
                        reportError("Cannot use '\(rvalue)' as rvalue in assignment", at: rvalue)
                        continue
                    }
                }
            }

            for (index, (lvalueType, rvalueType)) in zip(lvalueTypes, rvalueTypes).enumerated()
                where rvalueType != lvalueType
            {
                reportError("Cannot assign value of type '\(lvalueType)' to value of type '\(rvalueType)'", at: assign.rvalues[index])
            }

            node.value = Assign(lvalues: assign.lvalues, rvalues: assign.rvalues)

        case .block:
            let block = node.asBlock

            if !block.isForeign {
                let prevScope = currentScope
                currentScope = Scope(parent: currentScope)
                defer {
                    currentScope = prevScope
                }
            }
            for node in block.stmts {
                if block.isForeign {
                    guard node.kind == .declaration else {
                        if node.kind != .comment {
                            reportError("Only declarations are valid within a foreign block", at: node)
                        }
                        continue
                    }
                    node.asDeclaration.flags.insert(.foreign)
                }
                check(node: node)
            }

            node.value = Block(stmts: block.stmts, isForeign: block.isForeign, scope: currentScope)

        case .if:
            let iff = node.asIf

            let condType = checkExpr(node: iff.condition, desiredType: Type.bool)
            if condType != Type.bool {
                reportError("Cannot convert type '\(iff.condition)' to expected type 'bool'", at: iff.condition)
            }

            check(node: iff.thenStmt)

            if let elsé = iff.elseStmt {
                check(node: elsé)
            }

        case .for:
            let fór = node.asFor

            // This scope ensures that the `initializer`, `condition` and `step` of the
            // `for` statement have their own block. So, they can shadow values
            // and be shadowed themselves. This scope is not redundant.
            let prevScope = currentScope
            currentScope = Scope(parent: currentScope)
            defer {
                currentScope = prevScope
            }

            if let initializer = fór.initializer {
                check(node: initializer)
            }

            if let condition = fór.condition {
                let condType = checkExpr(node: condition, desiredType: Type.bool)
                if condType != Type.bool {
                    reportError("Cannot convert type '\(condition)' to expected type 'bool'", at: condition)
                }
            }

            if let step = fór.step {
                check(node: step)
            }

            check(node: fór.body)

        case .switch:
            let świtch = node.asSwitch
            var subjectType: Type?

            if let subject = świtch.subject {
                subjectType = checkExpr(node: subject)
            }

            var seenDefaultCase = false
            var checkedCases: [AstNode] = []
            for ćase in świtch.cases {
                guard ćase.kind == .case else {
                    reportError("Expected `case` block in `switch`, got: \(ćase)", at: ćase)
                    continue
                }

                guard !seenDefaultCase else {
                    reportError("Additional `case` blocks cannot be after a `default` block", at: ćase)
                    continue
                }

                let asCase = ćase.asCase
                if let match = asCase.condition {
                    let matchType = checkExpr(node: match)

                    if let subjectType = subjectType {
                        guard matchType == subjectType else {
                            reportError("Cannot convert type `\(matchType)` to expected type `\(subjectType)`", at: match)
                            continue
                        }
                    } else /* booleanesque */ {
                        guard matchType.isBooleanesque else {
                            reportError("Non-bool `\(match)` (type `\(matchType)`) used as condition", at: match)
                            continue
                        }
                    }
                } else {
                    seenDefaultCase = true
                }

                let prevScope = currentScope
                currentScope = Scope(parent: currentScope)
                defer {
                    currentScope = prevScope
                }

                check(node: asCase.block)

                ćase.value = Case(condition: asCase.condition, block: asCase.block, scope: currentScope)
                checkedCases.append(ćase)
            }

            guard seenDefaultCase else {
                reportError("A `switch` statement must have a default block\n    Note: try adding `case:` block", at: node)
                return
            }

            node.value = Switch(subject: świtch.subject, cases: checkedCases)

        case .return:
            let ret = node.asReturn

            let expectedTypes = currentExpectedReturnType!.isTuple ? currentExpectedReturnType!.asTuple.types : [currentExpectedReturnType!]

            var types: [Type] = []
            for (value, expectedType) in zip(ret.values, expectedTypes) {
                let type = checkExpr(node: value, desiredType: expectedType)
                types.append(type)

                if type != expectedType {
                    reportError("Cannot convert type '\(type)' to expected type '\(expectedType)'", at: value)
                }
            }

            if ret.values.count < expectedTypes.count && !currentExpectedReturnType!.isVoid {
                reportError("Not enough arguments to return", at: node)
                return
            }
            if ret.values.count > expectedTypes.count {
                reportError("Too many arguments to return", at: node)
                return
            }            

        case .import:
            let imp = node.asImport
            assert(imp.file.hasBeenParsed)

            var entity: Entity?
            if let symbol = imp.symbol, symbol.kind == .identifier {

                entity = Entity(ident: symbol.tokens.first!, flags: .file)
            } else if !imp.includeSymbolsInParentScope {

                let path = imp.path
                guard let name = pathToEntityName(path) else {
                    reportError("Cannot infer an import name for \(imp.path)", at: node.tokens[1])
                    attachNote("You will need to manually specify one: #import \"file-2.cte\" file2")
                    return
                }

                // end of string token
                let eos = node.tokens[1].end // the second token will always be the path string token
                let start = SourceLocation(line: eos.line, column: numericCast(numericCast(eos.column) - fileExtension.count - name.count - 1), file: eos.file)
                let end = SourceLocation(line: eos.line, column: numericCast(numericCast(eos.column) - fileExtension.count - 1), file: eos.file)
                let identifier = Token(kind: .ident, value: name, location: start ..< end)

                entity = Entity(ident: identifier, flags: .file)
            } else {
                assert(imp.includeSymbolsInParentScope)
            }

            imp.file.checkEmittingErrors()

            if imp.includeSymbolsInParentScope {
                for entity in imp.file.scope.members {
                    // TODO(vdka): Allow file scopes to export that which they import
                    guard !entity.flags.contains(.file) else {
                        continue
                    }
                    currentScope.insert(entity, scopeOwnsEntity: false)
                }
            }

            if let entity = entity {
                entity.memberScope = imp.file.scope
                entity.type = Type(value: Type.File(memberScope: imp.file.scope))
                currentScope.insert(entity)
            }

        case .library:
            let lib = node.asLibrary

            var entity: Entity
            if let symbol = lib.symbol {

                entity = Entity(ident: symbol.tokens.first!, flags: .library)
            } else {

                guard let name = pathToEntityName(lib.path) else {
                    reportError("Cannot infer an import name for \(lib.path)", at: node.tokens[1])
                    attachNote("You will need to manually specify one: #library \"libc++\" cpp")
                    return
                }

                // end of string token
                let eos = node.tokens[1].end // the second token will always be the path string token
                let start = SourceLocation(line: eos.line, column: numericCast(numericCast(eos.column) - fileExtension.count - name.count - 1), file: eos.file)
                let end = SourceLocation(line: eos.line, column: numericCast(numericCast(eos.column) - fileExtension.count - 1), file: eos.file)
                let identifier = Token(kind: .ident, value: name, location: start ..< end)

                entity = Entity(ident: identifier, flags: .library)
            }

            if lib.path != "libc" {

                guard let linkpath = resolveLibraryPath(lib.path, for: file.fullpath) else {
                    reportError("Failed to find resolve path for '\(lib.path)'", at: node.tokens[1])
                    return
                }
                file.linkedLibraries.insert(linkpath)
            }

            currentScope.insert(entity)

        default:
            fatalError("Unknown node kind: \(node.kind)")
        }
    }

    mutating func checkExpr(node: AstNode, desiredType: Type? = nil) -> Type {

        switch node.kind {
        case .identifier:
            let ident = node.asIdentifier.name
            guard let entity = self.currentScope.lookup(ident) else {
                reportError("Use of undefined identifier '\(ident)'", at: node)
                return Type.invalid
            }
            node.value = Identifier(name: ident, entity: entity)

            guard !entity.flags.contains(.library) else {
                reportError("Cannot use library as expression", at: node)
                return Type.invalid
            }

            if entity.type!.isFunction {
                return Type.makePointer(to: entity.type!)
            }

            return entity.type!

        case .litString:
            return Type.string

        case .litFloat:
            let lit = node.asFloatLiteral
            let type: Type
            if let desiredType = desiredType, desiredType.isNumber {
                guard desiredType.isFloatingPoint else {
                    reportError("Implicit conversion to integer may result in loss of information", at: node)
                    return Type.invalid
                }
                type = desiredType
            } else {
                type = FloatLiteral.defaultType
            }
            node.value = FloatLiteral(value: lit.value, type: type)
            return type

        case .litInteger:
            let lit = node.asIntegerLiteral
            let type: Type
            if let desiredType = desiredType, desiredType.isNumber {
                type = desiredType
            } else {
                type = IntegerLiteral.defaultType
            }
            node.value = IntegerLiteral(value: lit.value, type: type)
            return type

        case .variadic:
            let variadic = node.asVariadic
            var type = checkExpr(node: variadic.type, desiredType: desiredType)
            if type.isMetatype && type.asMetatype.instanceType.isAny && variadic.cCompatible {
                type = Type.makeMetatype(Type.cvargsAny)
            }
            return type

        case .function:
            var fn = node.asFunction

            let prevScope = currentScope
            currentScope = Scope(parent: currentScope)
            defer {
                currentScope = prevScope
            }

            var needsSpecialization = false
            var params: [Type] = []
            for (index, var param) in fn.parameters.enumerated() {
                assert(param.kind == .declaration || param.kind == .compileTime)
                if param.kind == .compileTime {
                    param = param.asCompileTime.stmt
                    param.asDeclaration.flags.insert(.compileTime)
                    node.asFunction.parameters[index] = param
                }
                if param.kind != .declaration {
                    reportError("Procedure literals must provide parameter names in their function prototype", at: param)
                }

                if param.asDeclaration.type!.kind == .variadic {
                    guard param === fn.parameters.last! else {
                        reportError("You can only use '..' with a functions final parameter", at: param)
                        return Type.invalid
                    }
                    let variadic = param.asDeclaration.type!.asVariadic

                    if variadic.cCompatible {
                        node.asFunction.flags.insert(.cVariadic)
                    } else {
                        node.asFunction.flags.insert(.variadic)
                    }
                }

                check(node: param)

                let entity = currentScope.members.last!

                if entity.flags.contains(.ct) {
                    needsSpecialization = true
                }

                params.append(entity.type!)
            }

            fn = node.asFunction

            var returnTypes: [Type] = []
            for returnType in fn.returnTypes {
                var type = checkExpr(node: returnType)
                type = lowerFromMetatype(type, atNode: returnType)
                returnTypes.append(type)
            }

            let returnType = Type.makeTuple(returnTypes)

            if returnType.isVoid && fn.isDiscardableResult {
                reportError("#discardable on void returning function is superflous", at: node.tokens[0])
            }

            let prevExpectedReturnType = currentExpectedReturnType
            currentExpectedReturnType = returnType
            defer {
                currentExpectedReturnType = prevExpectedReturnType
            }

            if !needsSpecialization { // polymorphic functions are checked when called
                check(node: fn.body)
            }

            let isVariadic = fn.flags.contains(.variadic)
            let functionType = Type.Function(node: node, params: params, returnType: returnType,
                                             isVariadic: isVariadic, isCVariadic: fn.isCVariadic,
                                             needsSpecialization: needsSpecialization)

            let type = Type(value: functionType, entity: Entity.anonymous)

            if needsSpecialization {

                node.value = PolymorphicFunction(parameters: fn.parameters, returnTypes: fn.returnTypes, body: fn.body, flags: fn.flags, type: type, specializations: [])
            } else {

                node.value = Function(
                    parameters: fn.parameters, returnTypes: fn.returnTypes, body: fn.body, flags: fn.flags,
                    scope: currentScope, type: type)
            }

            return type

        case .functionType:
            var fn = node.asFunctionType

            var params: [Type] = []
            for param in fn.parameters {

                var type: Type
                if param.kind == .declaration {

                    if param.asDeclaration.type!.kind == .variadic {
                        guard param === fn.parameters.last! else {
                            reportError("You can only use '..' with a functions final parameter", at: param)
                            return Type.invalid
                        }
                        let variadic = param.asDeclaration.type!.asVariadic

                        if variadic.cCompatible {
                            node.asFunctionType.flags.insert(.cVariadic)
                        }
                        node.asFunctionType.flags.insert(.variadic)
                    }

                    type = checkExpr(node: param.asDeclaration.type!)
                    type = lowerFromMetatype(type, atNode: param.asDeclaration.type!)
                } else {
                    if param.kind == .variadic {
                        guard param === fn.parameters.last! else {
                            reportError("You can only use '..' with a functions final parameter", at: param)
                            return Type.invalid
                        }
                        let variadic = param.asVariadic

                        if variadic.cCompatible {
                            node.asFunctionType.flags.insert(.cVariadic)
                        }
                        node.asFunctionType.flags.insert(.variadic)
                    }
                    type = checkExpr(node: param)
                    type = lowerFromMetatype(type, atNode: param)
                }

                params.append(type)
            }

            // reload this as the parameter check can modify the original node
            fn = node.asFunctionType

            var returnTypes: [Type] = []
            for returnType in fn.returnTypes {
                var type = checkExpr(node: returnType)
                type = lowerFromMetatype(type, atNode: returnType)
                returnTypes.append(type)
            }

            let returnType = Type.makeTuple(returnTypes)

            if returnType.isVoid && fn.isDiscardableResult {
                reportError("#discardable on void returning function is superflous", at: node.tokens[0])
            }

            let functionType = Type.Function(node: node, params: params, returnType: returnType,
                                             isVariadic: fn.isVariadic, isCVariadic: fn.isCVariadic,
                                             needsSpecialization: false)

            let instanceType = Type(value: functionType, entity: Entity.anonymous)
            let fnPointerType = Type.makePointer(to: instanceType)
            let type = Type.makeMetatype(fnPointerType)

            node.value = FunctionType(parameters: fn.parameters, returnTypes: fn.returnTypes, flags: fn.flags, type: type)

            return type

        case .pointerType:
            let pointerType = node.asPointerType
            var pointeeType = checkExpr(node: pointerType.pointee)

            pointeeType = lowerFromMetatype(pointeeType, atNode: pointerType.pointee)

            let instanceType = Type.makePointer(to: pointeeType)
            let type = Type.makeMetatype(instanceType)
            node.value = PointerType(pointee: pointerType.pointee, type: type)
            return type

        case .paren:
            let paren = node.asParen
            let type = checkExpr(node: paren.expr)
            node.value = Paren(expr: paren.expr, type: type)
            return type

        case .prefix:
            let prefix = node.asPrefix
            var type = checkExpr(node: prefix.expr)

            switch prefix.token.kind {
            case .plus, .minus:
                guard type == Type.f64 else {
                    reportError("Prefix operator '\(prefix.token)' is only valid on signed numeric types", at: prefix.expr)
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
                reportError("Prefix operator '\(prefix.token)', is invalid on type '\(type)'", at: prefix.expr)
                return Type.invalid
            }
            node.value = Prefix(token: prefix.token, expr: prefix.expr, type: type)
            return type

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
                reportError("Operator '\(infix.token) is not valid between '\(lhsType)' and '\(rhsType)' types", at: node)
                return Type.invalid
            }

            assert((lhsType == rhsType) || lCast != nil || rCast != nil, "We must have 2 same types or a way to acheive them by here")

            let isIntegerOp = lhsType.isInteger || rhsType.isInteger

            var type: Type
            switch infix.token.kind {
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

            node.value = Infix(token: infix.token, lhs: infix.lhs, rhs: infix.rhs, type: type, op: op, lhsCast: lCast, rhsCast: rCast)
            return type

        case .call:
            let call = node.asCall
            var calleeType = checkExpr(node: call.callee)

            if calleeType.isMetatype {
                return checkCast(callNode: node)
            }

            if calleeType.isFunctionPointer {
                calleeType = calleeType.asPointer.pointeeType
            }

            guard calleeType.isFunction else {
                reportError("Cannot call value of non-function type '\(calleeType)'", at: node)
                return Type.invalid
            }

            let calleeFn = calleeType.asFunction

            if calleeFn.needsSpecialization {

                return checkPolymorphicCall(callNode: node, calleeType: calleeType)
            }

            for (arg, expectedType) in zip(call.arguments, calleeFn.params) {

                let argType = checkExpr(node: arg, desiredType: expectedType)

                guard argType == expectedType || implicitlyConvert(argType, to: expectedType) else {
                    reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expectedType)'", at: arg)
                    continue
                }
            }

            if call.arguments.count > calleeFn.params.count {
                let excessArgs = call.arguments[calleeFn.params.count...]
                guard calleeType.asFunction.isVariadic else {
                    reportError("Too many arguments in call to \(call.callee)", at: excessArgs.first!)
                    return calleeType.asFunction.returnType
                }

                let expectedType = calleeFn.params.last!
                for arg in excessArgs {
                    let argType = checkExpr(node: arg, desiredType: expectedType)

                    guard argType == expectedType || implicitlyConvert(argType, to: expectedType) else {
                        reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expectedType)'", at: arg)
                        continue
                    }
                }
            }

            if call.arguments.count < calleeType.asFunction.params.count {
                guard calleeFn.isVariadic, call.arguments.count + 1 == calleeFn.params.count else {
                    reportError("Not enough arguments in call to '\(call.callee)", at: node)
                    return calleeFn.returnType
                }
            }

            node.value = Call(callee: call.callee, arguments: call.arguments, specialization: nil, type: calleeFn.returnType)

            return calleeFn.returnType

        case .memberAccess:
            let access = node.asMemberAccess

            let aggregateType = checkExpr(node: access.aggregate)

            guard let aggregateScope = aggregateType.memberScope else {
                reportError("'\(access.aggregate)' (type \(aggregateType)) is not an aggregate type", at: access.aggregate)
                return Type.invalid
            }

            guard let memberEntity = aggregateScope.lookup(access.memberName) else {
                reportError("Member '\(access.member)' not found in scope of '\(access.aggregate)'", at: access.member)
                return Type.invalid
            }

            node.value = MemberAccess(aggregate: access.aggregate, member: access.member, entity: memberEntity)

            return memberEntity.type!

        default:
            reportError("Cannot convert '\(node)' to an Expression", at: node)
            return Type.invalid
        }
    }

    mutating func checkCast(callNode: AstNode) -> Type {
        let call = callNode.asCall

        var targetType = checkExpr(node: call.callee)
        targetType = Type.lowerFromMetatype(targetType)

        guard call.arguments.count == 1, let arg = call.arguments.first else {
            if call.arguments.count == 0 {
                reportError("Missing argument for cast to \(targetType)", at: callNode)
            } else { // args.count > 1
                reportError("Too many arguments for cast to \(targetType)", at: callNode)
            }
            return Type.invalid
        }

        let argType = checkExpr(node: arg, desiredType: targetType)

        if argType == targetType {
            reportError("Unnecissary cast to same type", at: callNode)
            return targetType
        }

        let cast: OpCode.Cast
        if argType.compatibleWithExtOrTrunc(targetType) {

            if argType.isFloatingPoint {
                cast = (argType.width! > targetType.width!) ? .fpTrunc : .fpext
            } else if targetType.isSignedInteger {
                cast = (argType.width! > targetType.width!) ? .trunc : .sext
            } else if targetType.isUnsignedInteger {
                cast = (argType.width! > targetType.width!) ? .trunc : .zext
            } else {
                fatalError("This is should cover all bases where compatibleWithExtOrTrunc returns true")
            }
        } else if argType.isSignedInteger && targetType.isFloatingPoint {
            cast = .siToFP
        } else if argType.isUnsignedInteger && targetType.isFloatingPoint {
            cast = .uiToFP
        } else if argType.isFloatingPoint && targetType.isSignedInteger {
            cast = .fpToSI
        } else if argType.isFloatingPoint && targetType.isUnsignedInteger {
            cast = .fpToUI
        } else {
            reportError("Cannot cast between unrelated types '\(argType)' and '\(targetType)", at: callNode)
            return Type.invalid
        }

        callNode.value = Cast(callee: call.callee, arguments: call.arguments, type: targetType, cast: cast)
        return targetType
    }

    mutating func checkPolymorphicCall(callNode: AstNode, calleeType: Type) -> Type {
        let call = callNode.asCall
        var fnNode = calleeType.asFunction.node
        var fn = fnNode.asCheckedPolymorphicFunction

        var specializations: [Type] = []

        let paramEntities = fn.parameters.map({ $0.asCheckedDeclaration.entity })
        for (arg, expected) in zip(call.arguments, paramEntities).filter({ $0.1.flags.contains(.ct) }) {

            // TODO(vdka): Desired type
            let argType = checkExpr(node: arg)

            guard argType == expected.type! || argType.isMetatype && expected.type == Type.type else {
                reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expected.type!)'", at: arg)
                return Type.invalid // Don't even bother trying to recover from specialized function checking
            }

            specializations.append(argType)
        }

        // If there is already a matching specialization no need to recheck
        if let specialization = fn.specializations.firstMatching(specializations) {

            let runtimeArguments = zip(call.arguments, paramEntities)
                .filter({ !$0.1.flags.contains(.ct) })
                .map({ $0.0 })
            // check runtime arguments
            for (arg, expectedType) in zip(runtimeArguments, specialization.strippedType.asFunction.params) {

                let argType = checkExpr(node: arg, desiredType: expectedType)
                guard argType == expectedType else {
                    reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expectedType)'", at: arg)
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
        var paramsEntities: [Entity] = []
        var strippedParamTypes: [Type] = []
        var specializationIndices: [Int] = []
        for (index, param) in fn.parameters.enumerated() {
            assert(param.kind == .declaration)

            let decl = param.asCheckedDeclaration
            // Changed the param node value back to being unchecked
            param.value = AstNode.Declaration(identifier: decl.identifier, type: decl.type, value: decl.value,
                                              linkName: decl.linkName, flags: decl.flags)

            // check the declaration as usual.
            check(node: param)

            let entity = currentScope.members.last!

            if entity.flags.contains(.ct) {

                // Inject the type we are specializing to.
                entity.type = specializedTypeIterator.next()!
                specializationIndices.append(index)
            } else {
                strippedParamTypes.append(entity.type!)
            }

            paramsEntities.append(entity)
        }

        var returnTypes: [Type] = []
        for returnType in fn.returnTypes {
            var type = checkExpr(node: returnType)
            type = lowerFromMetatype(type, atNode: returnType)
            returnTypes.append(type)
        }

        let returnType = Type.makeTuple(returnTypes)

        let prevExpectedReturnType = currentExpectedReturnType
        currentExpectedReturnType = returnType
        defer {
            currentExpectedReturnType = prevExpectedReturnType
        }

        // Return to the calling scope to check the validity of the argument expressions
        // Once done return to the function scope to check the body
        let fnScope = currentScope
        currentScope = prevScope
        for (arg, expected) in zip(call.arguments, paramsEntities) {

            let argType = checkExpr(node: arg, desiredType: expected.type!)
            guard argType == expected.type! else {
                reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expected.type!)'", at: arg)
                continue
            }
        }
        currentScope = fnScope

        currentSpecializationCall = callNode
        check(node: fn.body)
        currentSpecializationCall = nil

        let strippedFunction = Type.Function(node: fnNode, params: strippedParamTypes, returnType: returnType,
                                             isVariadic: fn.isSpecialization, isCVariadic: fn.isCVariadic,
                                             needsSpecialization: false)
        let strippedType = Type(value: strippedFunction, entity: Entity.anonymous)

        var strippedParameters = fn.parameters
        for index in specializationIndices.reversed() {
            strippedParameters.remove(at: index)
        }

        let flags = fn.flags.union(.specialization)

        fnNode.value = Function(
            parameters: strippedParameters, returnTypes: fn.returnTypes, body: fn.body, flags: flags,
            scope: currentScope, type: strippedType)

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

    /// - Returns: Was a conversion performed
    func implicitlyConvert(_ type: Type, to targetType: Type) -> Bool {

        if targetType.isAny {
            fatalError("Implement this once we have an any type")
        }

        if targetType.isCVargAny {
            // No actual conversion need be done.
            return true
        }

        return false
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
            let entity = asCheckedIdentifier.entity
            return !(entity.flags.contains(.file) || entity.flags.contains(.library))

        default:
            return false
        }
    }

    var isRvalue: Bool {

        switch self.kind {
        case .identifier:
            let entity = asCheckedIdentifier.entity
            return !(entity.flags.contains(.file) || entity.flags.contains(.library))

        default:
            return !isStmt
        }
    }

    var isDiscardable: Bool {
        assert(!isStmt)

        guard self.kind == .call else {
            return false
        }

        let fn = self.asCheckedCall.callee.exprType.asFunction.node

        if fn.kind == .functionType {
            return fn.asFunctionType.isDiscardableResult
        }
        assert(fn.kind == .function)
        return fn.asFunction.isDiscardableResult
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

        static let defaultType: Type = Type.f64

        let value: Double

        let type: Type
    }

    struct IntegerLiteral: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.IntegerLiteral

        static let defaultType: Type = Type.i64

        let value: UInt64

        let type: Type
    }

    struct Function: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.Function

        var parameters: [AstNode]
        var returnTypes: [AstNode]
        let body: AstNode

        var flags: FunctionFlags

        /// The scope the parameters occur within
        let scope: Scope

        var type: Type
    }

    struct PolymorphicFunction: CheckedExpression, CheckedAstValue {
        static let astKind = AstKind.polymorphicFunction

        typealias UncheckedValue = AstNode.Function

        let parameters: [AstNode]
        let returnTypes: [AstNode]
        let body: AstNode
        let flags: FunctionFlags

        let type: Type

        var specializations: [FunctionSpecialization] = []
    }

    struct FunctionType: CheckedAstValue {
        typealias UncheckedValue = AstNode.FunctionType

        let parameters: [AstNode]
        let returnTypes: [AstNode]
        var flags: FunctionFlags

        let type: Type
    }

    struct PointerType: CheckedAstValue {
        typealias UncheckedValue = AstNode.PointerType

        let pointee: AstNode
        let type: Type
    }

    struct Declaration: CheckedAstValue {
        typealias UncheckedValue = AstNode.Declaration

        let identifier: AstNode
        var type: AstNode?
        let value: AstNode

        var linkName: String?

        var flags: DeclarationFlags

        let entity: Entity
    }

    struct Paren: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.Paren

        let expr: AstNode
        let type: Type
    }

    struct Prefix: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.Prefix

        let token: Token
        let expr: AstNode

        let type: Type
    }

    struct Infix: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.Infix

        let token: Token
        let lhs: AstNode
        let rhs: AstNode
        let type: Type

        let op: OpCode.Binary
        let lhsCast: OpCode.Cast?
        let rhsCast: OpCode.Cast?
    }

    struct Assign: CheckedAstValue {
        typealias UncheckedValue = AstNode.Assign

        let lvalues: [AstNode]
        let rvalues: [AstNode]
    }

    struct Call: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.Call

        let callee: AstNode
        let arguments: [AstNode]

        let specialization: FunctionSpecialization?
        let type: Type
    }

    struct Cast: CheckedExpression, CheckedAstValue {
        static let astKind = AstKind.cast

        typealias UncheckedValue = AstNode.Call

        let callee: AstNode
        let arguments: [AstNode]

        let type: Type
        let cast: OpCode.Cast
    }

    struct MemberAccess: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.MemberAccess

        let aggregate: AstNode
        let member: AstNode
        var memberName: String {
            return member.asIdentifier.name
        }

        let entity: Entity
        var type: Type {
            return entity.type!
        }
    }

    struct Block: CheckedAstValue {
        typealias UncheckedValue = AstNode.Block

        let stmts: [AstNode]
        var isForeign: Bool
        let scope: Scope
    }

    struct Switch: CheckedAstValue {
        typealias UncheckedValue = AstNode.Switch

        let subject: AstNode?
        let cases: [AstNode]
    }

    struct Case: CheckedAstValue {
        typealias UncheckedValue = AstNode.Case

        let condition: AstNode?
        let block: AstNode
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

extension CommonAssign {

    var rvalueIsCall: Bool {
        return rvalues.count == 1 && rvalues[0].kind == .call
    }
}

extension CommonDeclaration {

    var rvalueIsCall: Bool {
        return value.kind == .call
    }
}

extension Checker {

    func reportError(_ message: String, at node: AstNode, file: StaticString = #file, line: UInt = #line) {

        cte.reportError(message, at: node, file: file, line: line)
        if let currentSpecializationCall = currentSpecializationCall {
            attachNote("Called from: " + currentSpecializationCall.tokens.first!.start.description)
        }
    }

    func reportError(_ message: String, at token: Token, file: StaticString = #file, line: UInt = #line) {

        cte.reportError(message, at: token, file: file, line: line)
        if let currentSpecializationCall = currentSpecializationCall {
            attachNote("Called from: " + currentSpecializationCall.tokens.first!.start.description)
        }
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
