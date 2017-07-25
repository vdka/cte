
import LLVM

struct Checker {
    var file: SourceFile

    var context: Context

    init(file: SourceFile) {
        self.file = file

        let currentScope = Scope(parent: Scope.global, file: file)
        context = Context(scope: currentScope, previous: nil)
    }

    class Context {

        var scope: Scope
        var expectedReturnType: Type? = nil
        var specializationCallNode: AstNode? = nil

        var nextCase: AstNode?
        var switchLabel: Entity?
        var nearestSwitchLabel: Entity? {
            return switchLabel ?? previous?.nearestSwitchLabel
        }
        var inSwitch: Bool {
            return nearestSwitchLabel != nil
        }

        var loopLabel: Entity?
        var nearestLoopLabel: Entity? {
            return loopLabel ?? previous?.nearestLoopLabel
        }
        var inLoop: Bool {
            return nearestLoopLabel != nil
        }

        var nearestLabel: Entity? {
            assert(loopLabel == nil || switchLabel == nil)
            return loopLabel ?? switchLabel ?? previous?.nearestLabel
        }

        var previous: Context?

        init(scope: Scope, previous: Context?) {
            self.scope = scope
            self.previous = previous
        }
    }

    mutating func pushContext(owningNode: AstNode? = nil) {
        let newScope = Scope(parent: context.scope, owningNode: owningNode)
        context = Context(scope: newScope, previous: context)
    }

    mutating func popContext() {
        context = context.previous!
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
            if !(type == Type.invalid || node.isDiscardable || type.isVoid) {
                reportError("Expression of type '\(type)' is unused", at: node)
            }

        case .declaration:
            let decl = node.asDeclaration
            var expectedType: Type?
            var entities: [Entity] = []

            defer {
                for entity in entities {
                    context.scope.insert(entity)
                }
            }

            if let dType = decl.type {
                expectedType = checkExpr(node: dType)

                // Check if the declaration is a polymorphic type declaration
                if !(decl.isCompileTime && expectedType == Type.type) {
                    expectedType = lowerFromMetatype(expectedType!, atNode: dType)
                }
            }

            if decl.rvalueIsCall && decl.names.count > 1 {
                assert(!decl.isForeign)
                let type = checkCall(decl.values[0])
                let types = type.asTuple.types

                for (name, type) in zip(decl.names, types) {
                    assert(name.kind == .identifier)
                    if name.isDispose {
                        entities.append(Entity.anonymous)
                        continue
                    }
                    let identifierToken = name.tokens[0]
                    let entity = Entity(ident: identifierToken, type: type)

                    if decl.isCompileTime {
                        entity.flags.insert(.compileTime)
                    }

                    if type == Type.type {
                        entity.flags.insert(.type)
                    }

                    entities.append(entity)
                }

                node.value = Declaration(names: decl.names, type: decl.type, values: decl.values,
                                         linkName: decl.linkName, flags: decl.flags, entities: entities)

                return
            }

            if decl.values.isEmpty {

                let type = expectedType!
                for name in decl.names {
                    assert(name.kind == .identifier)
                    let identifierToken = name.tokens[0]
                    let entity = Entity(ident: identifierToken, type: type)

                    if decl.isCompileTime {
                        entity.flags.insert(.compileTime)
                    }

                    if type == Type.type {
                        entity.flags.insert(.type)
                    }

                    entities.append(entity)
                }
            } else {

                // NOTE: Calls with multiple returns are handled prior
                for (name, value) in zip(decl.names, decl.values) {
                    var type = checkExpr(node: value, desiredType: expectedType)
                    if name.isDispose {
                        entities.append(Entity.anonymous)
                        continue
                    }

                    if decl.isForeign, decl.isCompileTime {
                        guard type.isMetatype else {
                            reportError("Expected 'type' as rvalue for foreign symbol, got '\(type)'", at: value)
                            type = expectedType ?? Type.invalid
                            return
                        }
                        type = Type.lowerFromMetatype(type)

                        if value.kind == .functionType {
                            type = type.asPointer.pointeeType
                        }
                    }

                    if let expectedType = expectedType, type.isFunction && expectedType.isFunctionPointer && Type.makePointer(to: type) != expectedType {
                        reportError("Cannot convert value of type '\(type)' to specified type '\(expectedType)'", at: value)
                        type = expectedType
                    } else if let expectedType = expectedType, type != expectedType {
                        reportError("Cannot convert value of type '\(type)' to specified type '\(expectedType)'", at: value)
                        type = expectedType
                    }

                    assert(name.kind == .identifier)
                    let identifierToken = name.tokens[0]
                    let entity = Entity(ident: identifierToken, type: type)

                    if decl.isCompileTime {
                        entity.flags.insert(.compileTime)
                    }

                    if type == Type.type {
                        entity.flags.insert(.type)
                    }

                    entities.append(entity)
                }
            }

            node.value = Declaration(names: decl.names, type: decl.type, values: decl.values,
                                     linkName: decl.linkName, flags: decl.flags, entities: entities)

        case .assign:
            let assign = node.asAssign

            var lvalueTypes: [Type?] = []
            for lvalue in assign.lvalues {
                var type: Type?
                if !lvalue.isDispose {
                    type = checkExpr(node: lvalue)
                }
                lvalueTypes.append(type)

                guard lvalue.isLvalue else {
                    reportError("Cannot assign to '\(lvalue)'", at: lvalue)
                    continue
                }
            }
            var rvalueTypes: [Type] = []
            if assign.rvalueIsCall, let call = assign.rvalues.first {
                // NOTE: rvalue can also be a cast.
                let rvalueType = checkExpr(node: call)
                rvalueTypes = rvalueType.isTuple ? rvalueType.asTuple.types : [rvalueType]
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
                where lvalueType != nil && rvalueType != lvalueType
            {
                let rvalue = assign.rvalueIsCall ? assign.rvalues[0] : assign.rvalues[index]
                reportError("Cannot assign value of type '\(lvalueType!)' to value of type '\(rvalueType)'", at: rvalue)
            }

        case .parameter:
            let param = node.asParameter

            if param.isImplicitPolymorphic {
                let compileTime = param.type.asCompileTime
                guard compileTime.stmt.kind == .identifier else {
                    reportError("Expected identifier", at: compileTime.stmt)
                    return
                }

                let entity = Entity(ident: compileTime.stmt.tokens[0])
                entity.flags = .implicitType

                entity.type = Type.makePolymorphicMetatype(entity)

                context.scope.insert(entity)
            }

            var type = checkExpr(node: param.isImplicitPolymorphic ? param.type.asCompileTime.stmt : param.type)

            let identifierToken: Token
            var flags: Entity.Flag = []

            if param.isExplicitPolymorphic {
                identifierToken = param.name.asCompileTime.stmt.tokens[0]
                flags.insert(.compileTime)
            } else {
                type = lowerFromMetatype(type, atNode: param.type)
                identifierToken = param.name.tokens[0]
            }

            let entity = Entity(ident: identifierToken, type: type, flags: flags)
            context.scope.insert(entity)

            node.value = Parameter(name: param.name, type: param.type, entity: entity)

        case .block:
            let block = node.asBlock

            if !(block.isForeign || block.isFunction) {
                pushContext()
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
                if block.flags.contains(.specificCallingConvention) {
                    node.asDeclaration.flags.callingConvention = block.flags.callingConvention
                }
                check(node: node)
            }

            node.value = Block(stmts: block.stmts, flags: block.flags, scope: context.scope)

            if !(block.isForeign || block.isFunction) {
                popContext()
            }

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
            let foŕ = node.asFor

            // This scope ensures that the `initializer`, `condition` and `step` of the
            // `for` statement have their own block. So, they can shadow values
            // and be shadowed themselves. This scope is not redundant.
            pushContext(owningNode: node)

            let continueLabelEntity = Entity.makeLabel(for: foŕ.label ?? node)
            if foŕ.label != nil {
                context.scope.insert(continueLabelEntity)
            }

            context.loopLabel = continueLabelEntity

            if let initializer = foŕ.initializer {
                check(node: initializer)
            }

            if let condition = foŕ.condition {
                let condType = checkExpr(node: condition, desiredType: Type.bool)
                if condType != Type.bool {
                    reportError("Cannot convert type '\(condition)' to expected type 'bool'", at: condition)
                }
            }

            if let step = foŕ.step {
                check(node: step)
            }

            check(node: foŕ.body)
            popContext()

            node.value = For(label: foŕ.label,
                             initializer: foŕ.initializer, condition: foŕ.condition, step: foŕ.step, body: foŕ.body,
                             continueTarget: Ref(nil), breakTarget: Ref(nil))

        case .switch:
            let swítch = node.asSwitch
            var subjectType: Type?
            
            pushContext(owningNode: node)

            let labelEntity = Entity.makeLabel(for: swítch.label ?? node)
            if swítch.label != nil {
                context.scope.insert(labelEntity)
            }

            context.switchLabel = labelEntity

            if let subject = swítch.subject {
                subjectType = checkExpr(node: subject)
            }

            var seenDefaultCase = false
            var checkedCases: [AstNode] = []
            for (casé, nextCase) in swítch.cases.reversed().enumerated().map({ ($0.element, swítch.cases[safe: $0.offset - 1]) }) {
                guard casé.kind == .case else {
                    reportError("Expected `case` block in `switch`, got: \(casé)", at: casé)
                    continue
                }

                let asCase = casé.asCase
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
                    guard nextCase == nil else {
                        reportError("There must be at most one default case and it must be last", at: casé)
                        continue
                    }
                }

                context.nextCase = nextCase

                check(node: asCase.block)

                context.nextCase = nil

                casé.value = Case(condition: asCase.condition, block: asCase.block, scope: context.scope, fallthroughTarget: Ref(nil))

                checkedCases.append(casé)
            }

            guard seenDefaultCase else {
                reportError("A 'switch' statement must have a default block", at: node)
                attachNote("Try adding 'case:' block")
                return
            }

            popContext()

            node.value = Switch(label: swítch.label, subject: swítch.subject, cases: swítch.cases, breakTarget: Ref(nil))

        case .return:
            let ret = node.asReturn

            let expectedTypes = context.expectedReturnType!.asTuple.types

            var types: [Type] = []
            for (value, expectedType) in zip(ret.values, expectedTypes) {
                let type = checkExpr(node: value, desiredType: expectedType)
                types.append(type)

                if type != expectedType {
                    reportError("Cannot convert type '\(type)' to expected type '\(expectedType)'", at: value)
                }
            }

            if ret.values.count < expectedTypes.count && !context.expectedReturnType!.isVoid {
                reportError("Not enough arguments to return", at: node)
                return
            }
            if ret.values.count > expectedTypes.count {
                reportError("Too many arguments to return", at: node)
                return
            }

        case .break:
            let breaḱ = node.asBreak

            let labelEntity: Entity
            if let label = breaḱ.label {
                let name = label.asIdentifier.name
                guard let entity = context.scope.lookup(name) else {
                    reportError("Use of undefined identifier '\(label)'", at: node)
                    return
                }
                labelEntity = entity
            } else {
                guard let entity = context.nearestLabel else {
                    reportError("break outside of loop or switch", at: node)
                    return
                }
                labelEntity = entity
            }

            let target = labelEntity.owningScope.owningNode!

            node.value = Break(label: breaḱ.label, target: target)

        case .continue:
            let continué = node.asContinue

            let labelEntity: Entity
            if let label = continué.label {
                let name = label.asIdentifier.name
                guard let entity = context.scope.lookup(name) else {
                    reportError("Use of undefined identifier '\(label)'", at: node)
                    return
                }
                labelEntity = entity
            } else {
                guard let entity = context.nearestLoopLabel else {
                    reportError("continue outside of loop", at: node)
                    return
                }
                labelEntity = entity
            }

            let target = labelEntity.owningScope.owningNode!

            node.value = Continue(label: continué.label, target: target)

        case .fallthrough:
            guard context.inSwitch else {
                reportError("fallthrough outside of switch", at: node)
                return
            }

            let target = context.nextCase!

            node.value = Fallthrough(target: target)

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
                    context.scope.insert(entity, scopeOwnsEntity: false)
                }
            }

            if let entity = entity {
                entity.memberScope = imp.file.scope
                entity.type = Type(value: Type.File(memberScope: imp.file.scope))
                context.scope.insert(entity)
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

            context.scope.insert(entity)

        default:
            reportError("Unused expression '\(node)'", at: node)
        }
    }

    mutating func checkExpr(node: AstNode, desiredType: Type? = nil) -> Type {

        switch node.kind {
        case .identifier:
            let ident = node.asIdentifier.name
            guard let entity = context.scope.lookup(ident) else {
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

        case .compositeLiteral:
            let lit = node.asCompositeLiteral

            var type = checkExpr(node: lit.typeNode)
            type = lowerFromMetatype(type, atNode: lit.typeNode)

            switch type.kind {
            case .struct:
                if lit.elements.count > type.asStruct.fields.count {
                    reportError("Too many values in struct initializer", at: lit.elements[type.asStruct.fields.count])
                }

                for (element, field) in zip(lit.elements, type.asStruct.fields) {

                    let el = element.asCompositeLiteralField

                    if let identifier = el.identifier {

                        let name = identifier.asIdentifier.name

                        guard let field = type.asStruct.fields.first(where: { $0.name == name }) else {
                            reportError("Unknown field '\(identifier)' for '\(type)'", at: identifier)
                            continue
                        }

                        let type = checkExpr(node: el.value, desiredType: field.type)
                        guard type == field.type || implicitlyConvert(type, to: field.type) else {
                            reportError("Cannot convert type '\(type)' to expected type '\(field.type)'", at: el.value)
                            continue
                        }

                        element.value = CompositeLiteralField(identifier: identifier, value: el.value, structField: field, type: type)
                    } else {
                        let type = checkExpr(node: el.value, desiredType: field.type)
                        guard type == field.type || implicitlyConvert(type, to: field.type) else {
                            reportError("Cannot convert type '\(type)' to expected type '\(field.type)'", at: element)
                            continue
                        }

                        element.value = CompositeLiteralField(identifier: nil, value: el.value, structField: field, type: type)
                    }
                }

                node.value = CompositeLiteral(typeNode: lit.typeNode, elements: lit.elements, type: type)

                return type

            case .union:
                if lit.elements.count != 1 {
                    reportError("Multiple values in union literal is invalid", at: node)
                } else {
                    let el = lit.elements[0].asCompositeLiteralField

                    if let identifier = el.identifier {

                        let name = identifier.asIdentifier.name

                        guard let field = type.asUnion.fields.first(where: { $0.name == name }) else {
                            reportError("Unknown field '\(identifier)' for '\(type)'", at: identifier)
                            return type
                        }

                        let eltype = checkExpr(node: el.value, desiredType: field.type)
                        guard eltype == field.type || implicitlyConvert(type, to: field.type) else {
                            reportError("Cannot convert type '\(eltype)' to expected type '\(field.type)'", at: el.value)
                            return type
                        }

                        lit.elements[0].value = CompositeLiteralField(identifier: identifier, value: el.value, structField: nil, type: type)
                    } else {

                        let eltype = checkExpr(node: el.value)

                        var resolvedType: Type?
                        for unionType in type.asUnion.fields.map({ $0.type }) {

                            if eltype == unionType || implicitlyConvert(eltype, to: unionType) {
                                resolvedType = unionType
                                break
                            }
                        }

                        if resolvedType == nil {
                            reportError("No type in union matches the element type of '\(eltype)'", at: lit.elements[0])
                            attachNote("Expected one of:\n" + "    " + type.asUnion.fields.map({ $0.type.description }).joined(separator: "\n"))
                        } else {
                            lit.elements[0].value = CompositeLiteralField(identifier: nil, value: el.value, structField: nil, type: resolvedType!)
                        }
                    }
                }

                node.value = CompositeLiteral(typeNode: lit.typeNode, elements: lit.elements, type: type)

                return type

            default:
                reportError("Invalid type for composite literal", at: lit.typeNode)
                return Type.invalid
            }

        case .variadic:
            let variadic = node.asVariadic
            var type = checkExpr(node: variadic.type, desiredType: desiredType)
            if type.isMetatype && type.asMetatype.instanceType.isAny && variadic.cCompatible {
                type = Type.makeMetatype(Type.cvargsAny)
            }
            return type

        case .function:
            var fn = node.asFunction

            if !fn.isSpecialization {
                pushContext()
            }

            var needsSpecialization = false
            var params: [Type] = []
            for param in fn.parameters {
                assert(param.kind == .parameter)
                needsSpecialization = needsSpecialization || param.asParameter.isExplicitPolymorphic || param.asParameter.isImplicitPolymorphic

                if param.asParameter.isVariadic {
                    guard param === fn.parameters.last! else {
                        reportError("You can only use '..' with a functions final parameter", at: param)
                        return Type.invalid
                    }

                    if param.asParameter.isCVariadic {
                        fn.flags.insert(.cVariadic)
                    } else {
                        fn.flags.insert(.variadic)
                    }
                }

                check(node: param)

                let type = param.asCheckedParameter.entity.type!
                params.append(type)
            }

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

            context.expectedReturnType = returnType
            if !needsSpecialization { // polymorphic functions are checked when called
                check(node: fn.body)
            }
            context.expectedReturnType = nil

            var flags: Type.Function.Flag = .none
            if fn.isVariadic {
                flags.insert(.variadic)
            }
            if fn.isCVariadic {
                flags.insert(.cVariadic)
            }
            if needsSpecialization {
                flags.insert(.polymorphic)
            }

            let value = Type.Function(node: node, params: params, returnType: returnType, flags: flags)

            let type = Type(value: value, entity: Entity.anonymous)

            if needsSpecialization {

                node.value = PolymorphicFunction(parameters: fn.parameters, returnTypes: fn.returnTypes, body: fn.body, flags: fn.flags,
                                                 type: type, declaringScope: context.scope, specializations: [])
            } else {

                node.value = Function(parameters: fn.parameters, returnTypes: fn.returnTypes, body: fn.body, flags: fn.flags,
                                      scope: context.scope, type: type)
            }

            if !fn.isSpecialization {
                popContext()
            }

            return type

        case .functionType:
            var fn = node.asFunctionType

            var params: [Type] = []
            for param in fn.parameters {

                var type: Type
                if param.kind == .parameter {

                    if param.asParameter.type.kind == .variadic {
                        guard param === fn.parameters.last! else {
                            reportError("You can only use '..' with a functions final parameter", at: param)
                            return Type.invalid
                        }
                        let variadic = param.asParameter.type.asVariadic

                        if variadic.cCompatible {
                            node.asFunctionType.flags.insert(.cVariadic)
                        }
                        node.asFunctionType.flags.insert(.variadic)
                    }

                    type = checkExpr(node: param.asParameter.type)
                    type = lowerFromMetatype(type, atNode: param.asParameter.type)
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

            var flags: Type.Function.Flag = .none
            if fn.isVariadic {
                flags.insert(.variadic)
            }
            if fn.isCVariadic {
                flags.insert(.cVariadic)
            }

            let functionType = Type.Function(node: node, params: params, returnType: returnType, flags: flags)

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

        case .structType:
            let strućt = node.asStructType

            var width = 0
            var fields: [Type.Struct.Field] = []
            pushContext()
            for declaration in strućt.declarations {
                guard declaration.kind == .declaration else {
                    reportError("Unexpected \(declaration.kind), expected a declaration", at: declaration)
                    continue
                }

                check(node: declaration)

                for (index, entity) in declaration.asCheckedDeclaration.entities.enumerated() {

                    let field = Type.Struct.Field(ident: entity.ident, type: entity.type!, index: index, offset: width)
                    fields.append(field)

                    // FIXME: This will align fields to bytes. This maybe shouldn't be the default.
                    width = (width + (entity.type!.width ?? 0)).round(upToNearest: 8)
                }
            }
            popContext()

            let value = Type.Struct(node: node, fields: fields, ir: Ref(nil))
            let type = Type(entity: nil, width: width, flags: .none, value: value)

            return Type.makeMetatype(type)

        case .enumType:
            let enuḿ = node.asEnumType

            var assocType: Type?
            if let associatedType = enuḿ.associatedType {
                assocType = checkExpr(node: associatedType)
                assocType = lowerFromMetatype(assocType!, atNode: associatedType)
            }

            var currentValue = 0
            var typeCases: [Type.Enum.Case] = []
            pushContext()
            for casé in enuḿ.cases {

                switch casé.kind {
                case .identifier:
                    let typeCase = Type.Enum.Case(
                        ident: casé.tokens[0], value: currentValue, associatedValue: nil,
                        valueIr: Ref(nil), associatedValueIr: nil)

                    currentValue += 1
                    typeCases.append(typeCase)

                case .assign:
                    let assign = casé.asAssign
                    assert(assign.lvalues.count == 1)
                    assert(assign.rvalues.count == 1)

                    let ident = assign.lvalues[0]
                    let value = assign.rvalues[0]
                    guard ident.kind == .identifier else {
                        reportError("Expected identifier as lvalue", at: ident)
                        return Type.invalid
                    }

                    let valueType = checkExpr(node: value, desiredType: assocType)
                    if let associatedType = assocType, associatedType != valueType {
                        reportError("Expected type '\(associatedType)' got type '\(valueType)'", at: value)
                    }

                    if value.kind == .litInteger {
                        currentValue = Int(value.asIntegerLiteral.value)
                    }

                    let typeCase = Type.Enum.Case(
                        ident: assign.lvalues[0].tokens[0], value: currentValue, associatedValue: value,
                        valueIr: Ref(nil), associatedValueIr: Ref(nil))

                    typeCases.append(typeCase)

                    currentValue += 1

                default:
                    reportError("Unexpected \(casé.kind), expected either an identifier or an assignment", at: casé)
                }
            }
            popContext()
            let width = currentValue.bitsNeeded()

            let value = Type.Enum(node: node, associatedType: assocType, cases: typeCases, ir: Ref(nil))
            let type = Type(entity: nil, width: width, flags: .none, value: value)

            return Type.makeMetatype(type)

        case .unionType:
            let union = node.asUnionType

            var width = 0
            var fields: [Type.Union.Field] = []
            pushContext()
            for declaration in union.declarations {
                guard declaration.kind == .declaration else {
                    reportError("Unexpected \(declaration.kind), expected a declaration", at: declaration)
                    continue
                }

                check(node: declaration)

                for entity in declaration.asCheckedDeclaration.entities {

                    let field = Type.Union.Field(ident: entity.ident, type: entity.type!)
                    fields.append(field)

                    // FIXME: This will align fields to bytes. This maybe shouldn't be the default.
                    width = max(width, entity.type!.width!)
                }
            }
            popContext()
            width = width.round(upToNearest: 8)

            let value = Type.Union(node: node, fields: fields, ir: Ref(nil))
            let type = Type(entity: nil, width: width, flags: .none, value: value)


            return Type.makeMetatype(type)

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
                    reportError("Invalid operation '\(prefix.token)' on type '\(type)'", at: prefix.expr)
                    return Type.invalid
                }

            case .lt:
                guard type.kind == .pointer else {
                    reportError("Invalid operation '\(prefix.token)' on type '\(type)'", at: node)
                    return Type.invalid
                }

                type = type.asPointer.pointeeType

            case .ampersand:
                guard prefix.expr.isLvalue else {
                    reportError("Cannot take the address of a non lvalue", at: node)
                    return Type.invalid
                }
                type = Type.makePointer(to: type)

            case .not:
                guard prefix.expr.exprType.isBoolean else {
                    reportError("Invalid operation '\(prefix.token)' on type '\(type)'", at: prefix.expr)
                    return Type.invalid
                }
                type = Type.bool

            default:
                reportError("Invalid operation '\(prefix.token)' on type '\(type)'", at: prefix.expr)
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
                reportError("Invalid operation '\(infix.token)' between types '\(lhsType)' and '\(rhsType)'", at: node)
                return Type.invalid
            }

            assert((lhsType == rhsType) || lCast != nil || rCast != nil, "We must have 2 same types or a way to acheive them by here")

            let isIntegerOp = lhsType.isInteger || rhsType.isInteger

            var type: Type
            switch infix.token.kind {
            case .lt, .lte, .gt, .gte:
                guard lhsType.isNumber && rhsType.isNumber else {
                    reportError("Cannot compare '\(lhsType)' and '\(rhsType)'", at: node)
                    return Type.invalid
                }
                op = isIntegerOp ? .icmp : .fcmp
                type = Type.bool

            case .eq, .neq:
                guard lhsType.isNumber || lhsType.isBoolean else {
                    reportError("Cannot compare '\(lhsType)' and '\(rhsType)'", at: node)
                    return Type.invalid
                }
                op = (isIntegerOp || lhsType.isBoolean) ? .icmp : .fcmp
                type = Type.bool

            case .plus:
                op = isIntegerOp ? .add : .fadd
                type = resultType

            case .minus:
                op = isIntegerOp ? .sub : .fsub
                type = resultType

            case .asterix:
                op = isIntegerOp ? .mul : .fmul
                type = resultType

            case .divide:
                op = isIntegerOp ? .udiv : .fdiv
                type = resultType

            default:
                fatalError()
            }

            node.value = Infix(token: infix.token, lhs: infix.lhs, rhs: infix.rhs, type: type, op: op, lhsCast: lCast, rhsCast: rCast)
            return type

        case .call:
            return checkCall(node)

        case .access:
            let access = node.asAccess

            let aggregateType = checkExpr(node: access.aggregate)

            switch aggregateType.kind {
            case .file:
                guard let memberEntity = aggregateType.memberScope!.lookup(access.memberName) else {
                    reportError("Member '\(access.member)' not found in scope of '\(access.aggregate)'", at: access.member)
                    return Type.invalid
                }

                node.value = Access(aggregate: access.aggregate, member: access.member, entity: memberEntity)

                return memberEntity.type!

            case .struct:
                guard let field = aggregateType.asStruct.fields.first(where: { $0.name == access.memberName }) else {
                    reportError("Field '\(access.member)' not found in scope of '\(access.aggregate)'", at: access.member)
                    return Type.invalid
                }

                node.value = StructFieldAccess(aggregate: access.aggregate, member: access.member, field: field)

                return field.type

            case .union:
                guard let field = aggregateType.asUnion.fields.first(where: { $0.name == access.memberName }) else {
                    reportError("Field '\(access.member)' not found in scope of '\(access.aggregate)'", at: access.member)
                    return Type.invalid
                }

                node.value = UnionFieldAccess(aggregate: access.aggregate, member: access.member, field: field)

                return field.type

            case .metatype:
                let type = aggregateType.asMetatype.instanceType
                switch type.kind {
                case .enum:
                    guard let casé = type.asEnum.cases.first(where: { $0.name == access.memberName }) else {
                        reportError("Case '\(access.member)' not found in scope of '\(access.aggregate)'", at: access.member)
                        return Type.invalid
                    }

                    node.value = EnumCaseAccess(aggregate: access.aggregate, member: access.member, casé: casé, type: type)
                    return type

                default:
                    reportError("Not yet supported", at: node)
                    return Type.invalid
                }

            default:
                reportError("'\(access.aggregate)' (type \(aggregateType)) is not an aggregate type", at: access.aggregate)
                return Type.invalid
            }

        default:
            reportError("Cannot convert '\(node)' to an Expression", at: node)
            return Type.invalid
        }
    }

    mutating func checkCall(_ node: AstNode) -> Type {
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
            return Type.makeTuple([Type.invalid])
        }

        let calleeFn = calleeType.asFunction

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

        if calleeFn.needsSpecialization {
            return checkPolymorphicCall(callNode: node, calleeType: calleeType)
        }

        if calleeFn.isBuiltin {
            let builtin = lookupBuiltinFunction(call.callee)!
            if let customCheck = builtin.onCallCheck {
                var returnType = customCheck(&self, node)
                if returnType.asTuple.types.count == 1 {
                    returnType = returnType.asTuple.types[0]
                }

                node.value = Call(callee: call.callee, arguments: call.arguments, specialization: nil, builtinFunction: builtin, type: returnType)

                return returnType
            }
        }

        for (arg, expectedType) in zip(call.arguments, calleeFn.params) {

            let argType = checkExpr(node: arg, desiredType: expectedType)

            guard argType == expectedType || implicitlyConvert(argType, to: expectedType) else {
                reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expectedType)'", at: arg)
                continue
            }
        }

        var builtinFunction: BuiltinFunction?
        if calleeFn.isBuiltin {
            builtinFunction = lookupBuiltinFunction(call.callee)
        }

        var returnType = calleeFn.returnType
        if returnType.asTuple.types.count == 1 {
            returnType = returnType.asTuple.types[0]
        }

        node.value = Call(callee: call.callee, arguments: call.arguments, specialization: nil, builtinFunction: builtinFunction, type: returnType)

        return returnType
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

        var argType = checkExpr(node: arg, desiredType: targetType)

        var cast: OpCode.Cast = .bitCast

        defer {
            callNode.value = Cast(callee: call.callee, arguments: call.arguments, type: targetType, cast: cast)
        }

        if argType == targetType {
            reportError("Unnecissary cast to same type", at: callNode)
            return targetType
        }

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

        return targetType
    }

    mutating func checkPolymorphicCall(callNode: AstNode, calleeType: Type) -> Type {
        let call = callNode.asCall
        let functionLiteralNode = calleeType.asFunction.node
        let polymorphicFunction = functionLiteralNode.asCheckedPolymorphicFunction

        // FIXME: Leave this copy until after we have checked for existing specializations
        let generatedFunctionNode = functionLiteralNode.copy()
        var generatedFunction = generatedFunctionNode.asCheckedPolymorphicFunction.toUnchecked()
        generatedFunction = AstNode.Function(parameters: generatedFunction.parameters, returnTypes: generatedFunction.returnTypes,
                                     body: generatedFunction.body, flags: generatedFunction.flags)

        var specializationTypes: [Type] = []

        let functionScope = Scope(parent: functionLiteralNode.asCheckedPolymorphicFunction.declaringScope)

        var explicitIndices: [Int] = []
        for (index, (arg, param)) in zip(call.arguments, generatedFunction.parameters).enumerated()
            where param.asCheckedParameter.isExplicitPolymorphic || param.asCheckedParameter.isImplicitPolymorphic
        {
            let polymorphicParameter = param.asCheckedParameter
            let expectedType = polymorphicParameter.entity.type! // NOTE: This can only be relivant for explicit parameters.
            let argType = checkExpr(node: arg, desiredType: expectedType)

            if polymorphicParameter.isExplicitPolymorphic {

                guard argType == expectedType || argType.isMetatype && expectedType == Type.type else {
                    reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expectedType)'", at: arg)
                    return Type.invalid // Don't even bother trying to recover from specialized function checking
                }
                explicitIndices.append(index)
                specializationTypes.append(argType)

                polymorphicParameter.entity.type = argType

                functionScope.insert(polymorphicParameter.entity)
            } else if polymorphicParameter.isImplicitPolymorphic {

                // set the type of the polymorphic type entity to the type of the argument provided for it.
                let polymorphicType = Type.makeMetatype(argType)
                polymorphicParameter.entity.type!.entity!.type = polymorphicType
                specializationTypes.append(polymorphicType)

                param.asCheckedParameter.type = param.asCheckedParameter.type.asCompileTime.stmt

                functionScope.insert(polymorphicParameter.entity.type!.entity!)
            } else {

                guard argType == expectedType else {
                    reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expectedType)'", at: arg)
                    return Type.invalid // Don't even bother trying to recover from specialized function checking
                }
            }
        }

        var strippedArguments = call.arguments
        for index in explicitIndices.reversed() {
            generatedFunction.parameters.remove(at: index)
            strippedArguments.remove(at: index)
        }

        if let specialization = polymorphicFunction.specializations.firstMatching(specializationTypes) {

            for (arg, expectedType) in zip(strippedArguments, specialization.strippedType.asFunction.params)
                where !(arg.value is CheckedExpression)
            {
                let argType = checkExpr(node: arg, desiredType: expectedType)

                guard argType == expectedType || implicitlyConvert(argType, to: expectedType) else {
                    reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expectedType)'", at: arg)
                    continue
                }
            }

            let returnType = specialization.strippedType.asFunction.returnType
            callNode.value = Call(callee: call.callee, arguments: strippedArguments, specialization: specialization, builtinFunction: nil, type: returnType)

            return specialization.strippedType.asFunction.returnType
        }

        generatedFunction.flags.insert(.specialization)
        generatedFunctionNode.value = generatedFunction

        let prevScope = context.scope
        context.scope = functionScope
        context.specializationCallNode = callNode

        let type = checkExpr(node: generatedFunctionNode)

        context.scope = prevScope
        context.specializationCallNode = nil

        for (arg, expectedType) in zip(strippedArguments, type.asFunction.params)
            where !(arg.value is CheckedExpression)
        {
            let argType = checkExpr(node: arg, desiredType: expectedType)

            guard argType == expectedType || implicitlyConvert(argType, to: expectedType) else {
                reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expectedType)'", at: arg)
                continue
            }
        }

        let specialization = FunctionSpecialization(specializedTypes: specializationTypes, strippedType: type, generatedFunctionNode: generatedFunctionNode)

        let returnType = type.asFunction.returnType
        callNode.value = Call(callee: call.callee, arguments: strippedArguments, specialization: specialization, builtinFunction: nil, type: returnType)

        functionLiteralNode.asCheckedPolymorphicFunction.specializations.append(specialization)

        return type.asFunction.returnType
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
            if asIdentifier.name == "_" {
                return true
            }
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

    var isDispose: Bool {
        assert(!isStmt)

        guard self.kind == .identifier else {
            return false
        }

        return self.asIdentifier.name == "_"
    }
}


// MARK: Checked AstValue's

protocol CheckedAstValue: AstValue {
    associatedtype UncheckedValue: AstValue

    func toUnchecked() -> UncheckedValue
}

protocol CheckedExpression {
    var type: Type { get }
}

extension CheckedAstValue {
    static var astKind: AstKind {
        return UncheckedValue.astKind
    }

    func toUnchecked() -> UncheckedValue {

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

    struct CompositeLiteral: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.CompositeLiteral

        var typeNode: AstNode
        var elements: [AstNode]

        var type: Type
    }

    struct CompositeLiteralField: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.CompositeLiteralField

        var identifier: AstNode?
        var value: AstNode

        var structField: Type.Struct.Field?
        var type: Type
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

    // sourcery:NoCommon
    struct PolymorphicFunction: CheckedExpression, CheckedAstValue {
        static let astKind = AstKind.polymorphicFunction

        typealias UncheckedValue = AstNode.Function

        var parameters: [AstNode]
        var returnTypes: [AstNode]
        let body: AstNode
        var flags: FunctionFlags

        let type: Type

        let declaringScope: Scope

        var specializations: [FunctionSpecialization] = []
    }

    struct Parameter: CheckedAstValue {
        typealias UncheckedValue = AstNode.Parameter

        var name: AstNode
        var type: AstNode

        let entity: Entity
    }

    struct FunctionType: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.FunctionType

        let parameters: [AstNode]
        let returnTypes: [AstNode]
        var flags: FunctionFlags

        let type: Type
    }

    struct PointerType: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.PointerType

        let pointee: AstNode
        let type: Type
    }

    struct StructType: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.StructType

        let declarations: [AstNode]
        let type: Type
    }

    struct UnionType: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.UnionType

        let declarations: [AstNode]
        let type: Type
    }

    struct EnumType: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.EnumType

        let associatedType: AstNode?
        let cases: [AstNode]
        let type: Type
    }

    struct Declaration: CheckedAstValue {
        typealias UncheckedValue = AstNode.Declaration

        var names: [AstNode]
        var type: AstNode?
        var values: [AstNode]

        var linkName: String?
        var flags: DeclarationFlags

        let entities: [Entity]
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

    struct Call: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.Call

        let callee: AstNode
        let arguments: [AstNode]

        let specialization: FunctionSpecialization?
        let builtinFunction: BuiltinFunction?
        let type: Type
    }

    // sourcery:NoCommon
    struct Cast: CheckedExpression, CheckedAstValue {
        static let astKind = AstKind.cast

        typealias UncheckedValue = AstNode.Call

        let callee: AstNode
        let arguments: [AstNode]

        let type: Type
        let cast: OpCode.Cast
    }

    struct Access: CheckedExpression, CheckedAstValue {
        typealias UncheckedValue = AstNode.Access

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

    // sourcery:NoCommon
    struct StructFieldAccess: CheckedExpression, CheckedAstValue {
        static let astKind = AstKind.structFieldAccess
        typealias UncheckedValue = AstNode.Access

        let aggregate: AstNode
        let member: AstNode
        var memberName: String {
            return member.asIdentifier.name
        }

        let field: Type.Struct.Field
        var type: Type {
            return field.type
        }
    }

    // sourcery:NoCommon
    struct EnumCaseAccess: CheckedExpression, CheckedAstValue {
        static let astKind = AstKind.enumCaseAccess
        typealias UncheckedValue = AstNode.Access

        let aggregate: AstNode
        let member: AstNode
        var memberName: String {
            return member.asIdentifier.name
        }

        let casé: Type.Enum.Case
        var type: Type
    }

    // sourcery:NoCommon
    struct UnionFieldAccess: CheckedExpression, CheckedAstValue {
        static let astKind = AstKind.unionFieldAccess
        typealias UncheckedValue = AstNode.Access

        let aggregate: AstNode
        let member: AstNode
        var memberName: String {
            return member.asIdentifier.name
        }

        let field: Type.Union.Field
        var type: Type {
            return field.type
        }
    }

    struct Block: CheckedAstValue {
        typealias UncheckedValue = AstNode.Block

        let stmts: [AstNode]
        var flags: BlockFlag = []
        let scope: Scope
    }

    struct For: CheckedAstValue {
        typealias UncheckedValue = AstNode.For

        var label: AstNode?
        let initializer: AstNode?
        let condition: AstNode?
        let step: AstNode?
        let body: AstNode

        var continueTarget: Ref<BasicBlock?>
        var breakTarget: Ref<BasicBlock?>
    }

    struct Switch: AstValue {
        static let astKind = AstKind.switch

        var label: AstNode?
        let subject: AstNode?
        let cases: [AstNode]

        var breakTarget: Ref<BasicBlock?>
    }

    struct Case: CheckedAstValue {
        typealias UncheckedValue = AstNode.Case

        let condition: AstNode?
        let block: AstNode
        let scope: Scope

        var fallthroughTarget: Ref<BasicBlock?>
    }

    struct Break: CheckedAstValue {
        typealias UncheckedValue = AstNode.Break

        let label: AstNode?
        let target: AstNode
    }

    struct Continue: CheckedAstValue {
        typealias UncheckedValue = AstNode.Continue

        let label: AstNode?
        let target: AstNode
    }

    struct Fallthrough: CheckedAstValue {
        typealias UncheckedValue = AstNode.Fallthrough

        let target: AstNode
    }
}

class FunctionSpecialization {
    let specializedTypes: [Type]
    let strippedType: Type
    let generatedFunctionNode: AstNode
    var llvm: Function?

    init(specializedTypes: [Type], strippedType: Type, generatedFunctionNode: AstNode, llvm: Function? = nil) {
        assert(generatedFunctionNode.value is Checker.Function)
        self.specializedTypes = specializedTypes
        self.strippedType = strippedType
        self.generatedFunctionNode = generatedFunctionNode
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
        return values.count == 1 && values[0].kind == .call
    }
}

extension CommonParameter {

    var isVariadic: Bool {
        return type.kind == .variadic
    }

    var isCVariadic: Bool {
        return isVariadic && type.asVariadic.cCompatible
    }

    var isExplicitPolymorphic: Bool {
        return name.kind == .compileTime
    }

    var isImplicitPolymorphic: Bool {
        return type.kind == .compileTime
    }
}

extension Checker {

    func reportError(_ message: String, at node: AstNode, file: StaticString = #file, line: UInt = #line) {

        Core.reportError(message, at: node, file: file, line: line)
        if let currentSpecializationCall = context.specializationCallNode {
            attachNote("Called from: " + currentSpecializationCall.tokens.first!.start.description)
        }
    }

    func reportError(_ message: String, at token: Token, file: StaticString = #file, line: UInt = #line) {

        Core.reportError(message, at: token, file: file, line: line)
        if let currentSpecializationCall = context.specializationCallNode {
            attachNote("Called from: " + currentSpecializationCall.tokens.first!.start.description)
        }
    }
}

extension Array where Element == FunctionSpecialization {

    func firstMatching(_ specializationTypes: [Type]) -> FunctionSpecialization? {

        outer: for specialization in self {

            for (theirs, ours) in zip(specialization.specializedTypes, specializationTypes) {
                if theirs != ours {
                    continue outer
                }
            }
            return specialization
        }
        return nil
    }
}

