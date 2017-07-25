
import LLVM

var moduleName: String!

var module: Module = {
    return Module(name: moduleName)
}()

var builder: IRBuilder = {
    let builder = IRBuilder(module: module)

    // At this point we want to generate the ir for the builtin entities
    for builtinEntity in builtinEntities {
        _ = builtinEntity.gen(builder)
    }

    return builder
}()

var main: Function = {
    let mainType = FunctionType(argTypes: [], returnType: IntType.int32)
    let function = builder.addFunction("main", type: mainType)
    let entryBlock = function.appendBasicBlock(named: "entry")
    return function
}()

var memcpy: Function! = {
    let args: [IRType] = [PointerType.toVoid, PointerType.toVoid, IntType.int64, IntType.int32, IntType.int1]
    let type = FunctionType(argTypes: args, returnType: VoidType())
    return builder.addFunction("llvm.memcpy.p0i8.p0i8.i64", type: type)
}()

struct IRGenerator {

    var file: SourceFile
    var context: Context

    init(file: SourceFile) {
        self.file = file
        self.context = Context(mangledNamePrefix: "", previous: nil)

        if file.isInitialFile {
            // this is the file the compiler has been invoked upon
            builder.positionAtEnd(of: main.entryBlock!)
        }
    }

    class Context {
        var mangledNamePrefix: String
        var previous: Context?

        init(mangledNamePrefix: String, previous: Context?) {
            self.mangledNamePrefix = mangledNamePrefix
            self.previous = previous
        }
    }

    mutating func pushContext(scopeName: String) {
        context = Context(mangledNamePrefix: mangle(scopeName), previous: context)
    }

    mutating func popContext() {
        context = context.previous!
    }
}


extension IRGenerator {

    mutating func generate() {

        if !file.isInitialFile {
            pushContext(scopeName: file.pathFirstImportedAs.withoutExtension)
        }

        for node in file.nodes {
            emit(node: node)
        }

        if !file.isInitialFile {
            popContext()
        } else if file.isInitialFile {
            builder.buildRet(IntType.int32.constant(0))
        }
    }

    mutating func emit(node: AstNode) {

        switch node.kind {
        case .comment, .import, .library, .empty:
            return

        case .declaration:
            let decl = node.asCheckedDeclaration

            guard !decl.isFunction || decl.isForeign else {
                assert(decl.names.count == 1 && decl.entities.count == 1,
                       "For non foreign function declarations multiple declaration should be a checker error")
                decl.entities[0].value = emitExpr(node: decl.values[0], name: decl.entities[0].name)
                return
            }

            if decl.rvalueIsCall && decl.entities.count > 1 {
                let call = decl.values[0].asCheckedCall

                let retType = canonicalize(call.type)
                let stackAggregate = builder.buildAlloca(type: retType)
                let aggregate = emitCall(call)
                builder.buildStore(aggregate, to: stackAggregate)

                for (index, entity) in decl.entities.enumerated()
                    where entity !== Entity.anonymous
                {
                    let type = canonicalize(entity.type!)
                    let stackValue = builder.buildAlloca(type: type, name: entity.name)
                    let rvaluePtr = builder.buildStructGEP(stackAggregate, index: index)
                    let rvalue = builder.buildLoad(rvaluePtr)

                    builder.buildStore(rvalue, to: stackValue)

                    entity.value = stackValue
                }
                return
            }

            assert(decl.entities.count == decl.values.count)
            for (entity, value) in zip(decl.entities, decl.values) {
                guard !entity.type!.isMetatype else {
                    let type = entity.type!.asMetatype.instanceType
                    let irType = builder.createStruct(name: mangle(entity.name))

                    switch type.kind {
                    case .struct:
                        var irTypes: [IRType] = []
                        for field in type.asStruct.fields {
                            let fieldType = canonicalize(field.type)
                            irTypes.append(fieldType)
                        }
                        irType.setBody(irTypes)
                        type.asStruct.ir.val = irType

                    case .enum:
                        let body = IntType(width: type.width!)
                        irType.setBody([body])
                        type.asEnum.ir.val = irType

                        pushContext(scopeName: decl.names[0].asIdentifier.name)
                        // declare constant values for the cases
                        for casé in type.asEnum.cases {
                            if let associatedValue = casé.associatedValue, let associatedType = type.asEnum.associatedType, associatedType.kind != .integer {
                                var global: Global
                                if associatedValue.kind == .litString {
                                    global = builder.addGlobalString(name: mangle(casé.name) + "$associated", value: associatedValue.asStringLiteral.value)
                                } else {
                                    let ir = emitExpr(node: associatedValue)
                                    global = builder.addGlobal(mangle(casé.name) + "$associated", initializer: ir)
                                }
                                casé.associatedValueIr!.val = global
                            }

                            let bodyValueIr = body.constant(casé.value)
                            let ir = irType.constant(values: [bodyValueIr])
                            let global = builder.addGlobal(mangle(casé.name), initializer: ir)
                            casé.valueIr.val = global
                        }
                        popContext()

                    case .union:
                        let body = IntType(width: type.width!)
                        irType.setBody([body])
                        type.asUnion.ir.val = irType

                    default:
                        fatalError()
                    }
                    continue
                }

                let type = canonicalize(entity.type!)

                if decl.isForeign {
                    assert(decl.names.count == 1 && decl.entities.count == 1)
                    let name = decl.linkName ?? entity.name
                    if let type = type as? FunctionType {
                        let function = builder.addFunction(name, type: type)
                        entity.value = function
                        if decl.isSpecificCallingConvention {
                            function.callingConvention = decl.flags.callingConvention
                        }
                        return
                    }

                    var global = builder.addGlobal(name, type: type)
                    global.isExternallyInitialized = true
                    entity.value = global
                    return
                }

                if entity.flags.contains(.compileTime) {
                    let value = emitExpr(node: value)
                    var globalValue = builder.addGlobal(mangle(entity.name), initializer: value)
                    globalValue.isGlobalConstant = true
                    entity.value = globalValue
                    return
                }

                if let file = entity.owningScope.file, !file.isInitialFile {
                    let value = emitExpr(node: value)
                    let globalValue = builder.addGlobal(mangle(entity.name), initializer: value)
                    entity.value = globalValue
                    return
                }

                if Options.instance.contains(.emitIr) {

                    // Somehow Xcode 9 beta 3 includes a Swift compiler which thinks this is ambiguous.
                    // if let endOfAlloca = builder.insertBlock!.instructions.first(where: { !$0.isAAllocaInst }) {
                    //     builder.position(endOfAlloca, block: builder.insertBlock!)
                    // }

                    for inst in builder.insertBlock!.instructions {
                        guard !inst.isAAllocaInst else {
                            continue
                        }
                        builder.position(inst, block: builder.insertBlock!)
                        break
                    }
                }

                let stackValue = builder.buildAlloca(type: type, name: entity.name)

                if Options.instance.contains(.emitIr) {
                    builder.positionAtEnd(of: builder.insertBlock!)
                }

                entity.value = stackValue

                guard value != .empty else {
                    return
                }

                let value = emitExpr(node: value, name: entity.name)

                builder.buildStore(value, to: stackValue)
            }

        case .assign:
            let assign = node.asAssign

            if assign.rvalueIsCall && assign.lvalues.count > 1 {
                let call = assign.rvalues[0].asCheckedCall

                let retType = canonicalize(call.type)
                let stackAggregate = builder.buildAlloca(type: retType)
                let aggregate = emitCall(call)
                builder.buildStore(aggregate, to: stackAggregate)

                for (index, lvalue) in assign.lvalues.enumerated()
                    where !lvalue.isDispose
                {
                    let lvalueAddress = emitExpr(node: lvalue, returnAddress: true)
                    let rvaluePtr = builder.buildStructGEP(stackAggregate, index: index)
                    let rvalue = builder.buildLoad(rvaluePtr)
                    builder.buildStore(rvalue, to: lvalueAddress)
                }
                return
            }

            var rvalues: [IRValue] = []
            for rvalue in assign.rvalues {
                let rvalue = emitExpr(node: rvalue)
                rvalues.append(rvalue)
            }

            for (lvalue, rvalue) in zip(assign.lvalues, rvalues)
                where !lvalue.isDispose
            {
                let lvalueAddress = emitExpr(node: lvalue, returnAddress: true)
                builder.buildStore(rvalue, to: lvalueAddress)
            }

        case .parameter:
            let param = node.asCheckedParameter

            let type = canonicalize(param.entity.type!)

            if Options.instance.contains(.emitIr) {

                // Somehow Xcode 9 beta 3 includes a Swift compiler which thinks this is ambiguous.
                // if let endOfAlloca = builder.insertBlock!.instructions.first(where: { !$0.isAAllocaInst }) {
                //     builder.position(endOfAlloca, block: builder.insertBlock!)
                // }
                for inst in builder.insertBlock!.instructions {
                    guard !inst.isAAllocaInst else {
                        continue
                    }
                    builder.position(inst, block: builder.insertBlock!)
                    break
                }
            }

            let stackValue = builder.buildAlloca(type: type, name: param.entity.name)

            if Options.instance.contains(.emitIr) {
                builder.positionAtEnd(of: builder.insertBlock!)
            }

            param.entity.value = stackValue

        case .block:
            let block = node.asCheckedBlock
            for stmt in block.stmts {
                emit(node: stmt)
            }

        case .if:
            let iff = node.asIf

            let condition = emitExpr(node: iff.condition)

            let ln = node.tokens.first!.start.line

            let thenBlock = builder.currentFunction!.appendBasicBlock(named: "if.then.ln.\(ln)")
            let elseBlock = iff.elseStmt.map({ _ in builder.currentFunction!.appendBasicBlock(named: "if.else.ln.\(ln)") })
            let postBlock = builder.currentFunction!.appendBasicBlock(named: "if.post.ln.\(ln)")

            if let elseBlock = elseBlock {
                builder.buildCondBr(condition: condition, then: thenBlock, else: elseBlock)
            } else {
                builder.buildCondBr(condition: condition, then: thenBlock, else: postBlock)
            }

            builder.positionAtEnd(of: thenBlock)
            emit(node: iff.thenStmt)

            if let elsé = iff.elseStmt {
                builder.positionAtEnd(of: elseBlock!)
                emit(node: elsé)

                if elseBlock!.terminator != nil && thenBlock.terminator != nil {
                    postBlock.removeFromParent()

                    return
                }
            }

            builder.positionAtEnd(of: postBlock)

        case .for:
            let foŕ = node.asCheckedFor
            emitFor(foŕ)

        case .return:
            let ret = node.asReturn
            var values: [IRValue] = []
            for value in ret.values {
                let irValue = emitExpr(node: value)
                values.append(irValue)
            }

            switch values.count {
            case 0:
                builder.buildRetVoid()

            case 1:
                builder.buildRet(values[0])

            default:
                builder.buildRetAggregate(of: values)
            }

        case .switch:
            let swítch = node.asCheckedSwitch
            if swítch.subject == nil {
                emitBSwitch(swítch)
            } else {
                emitSwitch(swítch)
            }

        case .call:
            emitCall(node.asCheckedCall)

        case .break:
            let target = node.asCheckedBreak.target

            switch target.kind {
            case .for:
                builder.buildBr(target.asCheckedFor.breakTarget.val!)
            case .switch:
                builder.buildBr(target.asCheckedSwitch.breakTarget.val!)
            default:
                fatalError()
            }

        case .continue:
            let target = node.asCheckedContinue.target
            builder.buildBr(target.asCheckedFor.continueTarget.val!)

        case .fallthrough:
            let target = node.asCheckedCase
            builder.buildBr(target.fallthroughTarget.val!)

        default:
            fatalError()
        }
    }

    mutating func emitExpr(node: AstNode, returnAddress: Bool = false, name: String = "") -> IRValue {

        switch node.kind {
        case .litInteger:
            let lit = node.asCheckedIntegerLiteral
            let type = canonicalize(lit.type)
            switch type {
            case let type as IntType:
                return type.constant(lit.value)

            case let type as FloatType:
                return type.constant(Double(lit.value))

            default:
                fatalError()
            }

        case .litFloat:
            let lit = node.asCheckedFloatLiteral
            let type = canonicalize(lit.type) as! FloatType
            return type.constant(lit.value)

        case .litString:
            return builder.buildGlobalStringPtr(node.asStringLiteral.value)

        case .compositeLiteral:
            let lit = node.asCheckedCompositeLiteral

            switch lit.type.kind {
            case .struct:
                let type = canonicalize(lit.type) as! StructType
                var ir = type.undef()
                for element in lit.elements {
                    let field = element.asCheckedCompositeLiteralField

                    let val = emitExpr(node: element)
                    ir = builder.buildInsertValue(aggregate: ir, element: val, index: field.structField!.index)
                }
                return ir

            case .union:
                let unionType = (canonicalize(lit.type) as! StructType)
                let unionIntType = unionType.elementTypes[0]
                let elementIntType = IntType(width: lit.elements[0].exprType.width!)

                var ir = emitExpr(node: lit.elements[0])

                // cast the emitted value to an integer value of the same width
                ir = builder.buildBitCast(ir, type: elementIntType)

                // zext if needed to make the integer value into the width we need
                ir = builder.buildZExtOrBitCast(ir, type: unionIntType)

                var union = unionType.undef()
                union = builder.buildInsertValue(aggregate: union, element: ir, index: 0)

                return union

            default:
                fatalError()
            }

        case .compositeLiteralField:
            let field = node.asCheckedCompositeLiteralField
            return emitExpr(node: field.value)

        case .identifier:
            let ident = node.asCheckedIdentifier
            let stackValue = ident.entity.value!
            if returnAddress || ident.entity.type!.isFunction {
                return stackValue
            }
            return builder.buildLoad(stackValue)

        case .paren:
            return emitExpr(node: node.asCheckedParen.expr)

        case .prefix:
            return emitPrefix(node.asCheckedPrefix)

        case .infix:
            return emitInfix(node.asCheckedInfix)

        case .polymorphicFunction:
            emitPolymorphicFunction(named: name, fn: node.asCheckedPolymorphicFunction)
            return VoidType().undef()

        case .function:
            return emitFunction(named: name, node.asCheckedFunction)

        case .structType, .functionType, .pointerType:
            return VoidType().null()

        case .call:
            return emitCall(node.asCheckedCall)

        case .cast:
            let cast = node.asCheckedCast
            let val = emitExpr(node: cast.arguments.first!)
            return builder.buildCast(cast.cast, value: val, type: canonicalize(cast.type))

        case .access:
            let access = node.asCheckedAccess
            if access.entity.owningScope.isFile {
                if access.entity.type!.isFunction {
                    return access.entity.value!
                }
                return builder.buildLoad(access.entity.value!)
            }
            fatalError("Only file entities have child scopes currently")

        case .structFieldAccess:
            let access = node.asCheckedStructFieldAccess

            let lvalue = emitExpr(node: access.aggregate, returnAddress: true)

            let fieldAddress = builder.buildStructGEP(lvalue, index: access.field.index)

            if returnAddress {
                return fieldAddress
            }
            return builder.buildLoad(fieldAddress)

        case .enumCaseAccess:
            let access = node.asCheckedEnumCaseAccess

            if let associatedValueIr = access.casé.associatedValueIr?.val {

                if returnAddress {
                    return associatedValueIr
                }
                return builder.buildLoad(associatedValueIr)
            }

            let ir = access.casé.valueIr.val!

            if returnAddress {
                return ir
            }
            return builder.buildLoad(ir)

        case .unionFieldAccess:
            let access = node.asCheckedUnionFieldAccess

            var ir = emitExpr(node: access.aggregate, returnAddress: true)
            ir = builder.buildBitCast(ir, type: PointerType(pointee: canonicalize(node.exprType)))

            if returnAddress {
                return ir
            }
            return builder.buildLoad(ir)

        default:
            fatalError()
        }
    }

    mutating func emitPrefix(_ prefix: Checker.Prefix) -> IRValue {

        if prefix.token.kind == .ampersand {
            return emitExpr(node: prefix.expr, returnAddress: true)
        }

        let expr = emitExpr(node: prefix.expr)

        switch prefix.token.kind {
        case .plus:
            return expr

        case .minus:
            return builder.buildNeg(expr)

        case .lt:
            return builder.buildLoad(expr)

        case .not:
            return builder.buildNeg(expr)

        default:
            fatalError()
        }
    }

    mutating func emitInfix(_ infix: Checker.Infix) -> IRValue {

        var lhs = emitExpr(node: infix.lhs)
        var rhs = emitExpr(node: infix.rhs)
        if let castOp = infix.lhsCast {
            lhs = builder.buildCast(castOp, value: lhs, type: canonicalize(infix.rhs.exprType))
        } else if let castOp = infix.rhsCast {
            rhs = builder.buildCast(castOp, value: rhs, type: canonicalize(infix.lhs.exprType))
        }

        switch infix.op {
        case .icmp:
            let isSigned = infix.lhs.exprType.isSignedInteger
            var pred: IntPredicate
            switch infix.token.kind {
            case .lt:  pred = isSigned ? .signedLessThan : .unsignedLessThan
            case .gt:  pred = isSigned ? .signedGreaterThan : .unsignedGreaterThan
            case .lte: pred = isSigned ? .signedLessThanOrEqual : .unsignedLessThanOrEqual
            case .gte: pred = isSigned ? .signedGreaterThanOrEqual : .unsignedGreaterThanOrEqual
            case .eq:  pred = .equal
            case .neq: pred = .notEqual
            default:
                fatalError()
            }
            return builder.buildICmp(lhs, rhs, pred)

        case .fcmp:
            var pred: RealPredicate
            switch infix.token.kind {
            case .lt:  pred = .orderedLessThan
            case .gt:  pred = .orderedGreaterThan
            case .lte: pred = .orderedLessThanOrEqual
            case .gte: pred = .orderedGreaterThanOrEqual
            case .eq:  pred = .orderedEqual
            case .neq: pred = .orderedNotEqual
            default:
                fatalError()
            }
            return builder.buildFCmp(lhs, rhs, pred)

        default:
            return builder.buildBinaryOperation(infix.op, lhs, rhs)
        }
    }

    @discardableResult
    mutating func emitCall(_ call: Checker.Call) -> IRValue {

        if let builtinFunction = call.builtinFunction {
            return builtinFunction.generate(builtinFunction, call.arguments, module, builder)
        }

        var callee: IRValue
        if let specialization = call.specialization {
            callee = specialization.llvm!
        } else if call.callee.exprType.isFunctionPointer {
            callee = emitExpr(node: call.callee)
        } else {
            callee = emitExpr(node: call.callee, returnAddress: true)
        }

        let args = call.arguments.map({ emitExpr(node: $0) })

        return builder.buildCall(callee, args: args)
    }

    mutating func emitFunction(named name: String, _ fn: Checker.Function) -> Function {

        let function = builder.addFunction(mangle(name), type: canonicalize(fn.type) as! FunctionType)

        let lastBlock = builder.insertBlock

        let entryBlock = function.appendBasicBlock(named: "entry")
        builder.positionAtEnd(of: entryBlock)
        defer {
            if let lastBlock = lastBlock {
                builder.positionAtEnd(of: lastBlock)
            }
        }

        for (param, var irParam) in zip(fn.parameters, function.parameters) {

            let entity = param.asCheckedParameter.entity
            irParam.name = entity.name

            emit(node: param)

            builder.buildStore(irParam, to: entity.value!)
        }

        pushContext(scopeName: name)
        emit(node: fn.body)
        popContext()

        return function
    }

    mutating func emitPolymorphicFunction(named name: String, fn: Checker.PolymorphicFunction) {

        for specialization in fn.specializations {
            let fn = specialization.generatedFunctionNode.asCheckedFunction

            let suffix = specialization.specializedTypes.reduce("", { $0 + "$" + $1.asMetatype.instanceType.description })
            specialization.llvm = emitFunction(named: name + suffix, fn)
        }
    }

    mutating func emitFor(_ foŕ: Checker.For) {
        let currentFunc = builder.currentFunction!

        var loopBody: BasicBlock
        var loopPost: BasicBlock
        var loopCond: BasicBlock?
        var loopStep: BasicBlock?

        if let initializer = foŕ.initializer {
            emit(node: initializer)
        }

        if let condition = foŕ.condition {
            loopCond = currentFunc.appendBasicBlock(named: "for.cond")
            if foŕ.step != nil {
                loopStep = currentFunc.appendBasicBlock(named: "for.step")
            }

            loopBody = currentFunc.appendBasicBlock(named: "for.body")
            loopPost = currentFunc.appendBasicBlock(named: "for.post")

            builder.buildBr(loopCond!)
            builder.positionAtEnd(of: loopCond!)

            let condVal = emitExpr(node: condition)
            builder.buildCondBr(condition: condVal, then: loopBody, else: loopPost)
        } else {
            if foŕ.step != nil {
                loopStep = currentFunc.appendBasicBlock(named: "for.step")
            }

            loopBody = currentFunc.appendBasicBlock(named: "for.body")
            loopPost = currentFunc.appendBasicBlock(named: "for.post")

            builder.buildBr(loopBody)
        }

        foŕ.breakTarget.val = loopPost
        foŕ.continueTarget.val = loopCond ?? loopStep ?? loopBody
        builder.positionAtEnd(of: loopBody)
        defer {
            loopPost.moveAfter(builder.currentFunction!.lastBlock!)
        }

        emit(node: foŕ.body)

        let hasJump = builder.insertBlock?.terminator != nil

        if let step = foŕ.step {
            if !hasJump {
                builder.buildBr(loopStep!)
            }

            builder.positionAtEnd(of: loopStep!)
            emit(node: step)
            builder.buildBr(loopCond!)
        } else if let loopCond = loopCond {
            // `for x < 5 { /* ... */ }` || `for i := 1; x < 5; { /* ... */ }`
            if !hasJump {
                builder.buildBr(loopCond)
            }
        } else {
            // `for { /* ... */ }`
            if !hasJump {
                builder.buildBr(loopBody)
            }
        }

        builder.positionAtEnd(of: loopPost)
    }

    mutating func emitSwitch(_ swítch: Checker.Switch) {
        let subject = swítch.subject!

        let ln = swítch.cases.first!.tokens[0].start.line

        let currentFunc = builder.currentFunction!
        let currentBlock = builder.insertBlock!

        let postBlock = currentFunc.appendBasicBlock(named: "switch.post.ln.\(ln)")
        swítch.breakTarget.val = postBlock
        defer {
            postBlock.moveAfter(currentFunc.lastBlock!)
        }

        var thenBlocks: [BasicBlock] = []

        for i in swítch.cases.indices {
            let ln = swítch.cases[i].tokens.first!.start.line
            if i != swítch.cases.lastIndex {
                let thenBlock = currentFunc.appendBasicBlock(named: "switch.then.ln.\(ln)")
                thenBlocks.append(thenBlock)
            } else {
                let thenBlock = currentFunc.appendBasicBlock(named: "switch.default.ln.\(ln)")
                thenBlocks.append(thenBlock)
            }
        }

        let value = emitExpr(node: subject)
        var constants: [IRValue] = []
        for (i, casé) in swítch.cases.map({ $0.asCheckedCase }).enumerated() {

            let thenBlock = thenBlocks[i]
            casé.fallthroughTarget.val = thenBlocks[safe: i + 1]

            if let match = casé.condition {
                let val = emitExpr(node: match)
                constants.append(val)
            }

            builder.positionAtEnd(of: thenBlock)

            emit(node: casé.block)

            if builder.insertBlock!.terminator == nil {
                builder.buildBr(postBlock)
            }
            assert(thenBlock.terminator != nil)

            builder.positionAtEnd(of: currentBlock)
        }

        let irSwitch = builder.buildSwitch(value, else: thenBlocks.last!, caseCount: thenBlocks.count)
        for (constant, block) in zip(constants, thenBlocks) {
            irSwitch.addCase(constant, block)
        }

        builder.positionAtEnd(of: postBlock)
    }

    mutating func emitBSwitch(_ swítch: Checker.Switch) {
        let ln = swítch.cases.first!.tokens[0].start.line

        let currentFunc = builder.currentFunction!
        let currentBlock = builder.insertBlock!

        let postBlock = currentFunc.appendBasicBlock(named: "switch.post.ln.\(ln)")
        swítch.breakTarget.val = postBlock
        defer {
            postBlock.moveAfter(currentFunc.lastBlock!)
        }

        var condBlocks: [BasicBlock] = []
        var thenBlocks: [BasicBlock] = []

        for i in swítch.cases.indices {
            let ln = swítch.cases[i].tokens.first!.start.line
            let condBlock = currentFunc.appendBasicBlock(named: "switch.cond.ln.\(ln)")
            condBlocks.append(condBlock)
            let thenBlock = currentFunc.appendBasicBlock(named: "switch.then.ln.\(ln)")
            thenBlocks.append(thenBlock)
        }

        builder.positionAtEnd(of: currentBlock)

        for (i, casé) in swítch.cases.map({ $0.asCheckedCase }).enumerated() {

            let condBlock = i == 0 ? currentBlock : condBlocks[i]
            let nextCondBlock = condBlocks[safe: i + 1]

            let thenBlock = thenBlocks[i]
            casé.fallthroughTarget.val = thenBlocks[safe: i + 1]

            builder.positionAtEnd(of: condBlock)

            if let match = casé.condition {
                let cond = emitExpr(node: match)
                builder.buildCondBr(condition: cond, then: thenBlock, else: nextCondBlock ?? postBlock)
            } else {
                // this is the default case. Will just jump to the `then` block
                builder.buildBr(thenBlock)
            }

            builder.positionAtEnd(of: thenBlock)
            emit(node: casé.block)

            if builder.insertBlock!.terminator == nil {
                builder.buildBr(postBlock)
            }
        }

        condBlocks[0].removeFromParent()

        postBlock.moveAfter(thenBlocks.last!)
        builder.positionAtEnd(of: postBlock)
    }

    func mangle(_ name: String) -> String {
        return (context.mangledNamePrefix.isEmpty ? "" : context.mangledNamePrefix + ".") + name
    }
}

func canonicalize(_ type: Type) -> IRType {

    switch type.kind {
    case .void:
        return VoidType()

    case .any:
        fatalError()

    case .cvargsAny:
        fatalError()

    case .integer:
        return IntType(width: type.width!)

    case .floatingPoint where type.width == 16:
        return FloatType.half

    case .floatingPoint where type.width == 32:
        return FloatType.float

    case .floatingPoint where type.width == 64:
        return FloatType.double

    case .floatingPoint where type.width == 80:
        return FloatType.x86FP80

    case .floatingPoint where type.width == 128:
        return FloatType.fp128

    case .floatingPoint:
        fatalError("Unsupported width for floating point type")

    case .boolean:
        return IntType.int1

    case .function:
        let fn = type.asFunction

        var paramTypes: [IRType] = []

        let requiredParams = fn.isVariadic ? fn.params[..<fn.params.lastIndex] : ArraySlice(fn.params)
        for param in requiredParams {

            if !param.isCVargAny {
                let type = canonicalize(param)
                paramTypes.append(type)
            }
        }

        let retType = canonicalize(fn.returnType)

        return FunctionType(argTypes: paramTypes, returnType: retType, isVarArg: fn.isCVariadic)

    case .struct:
        return type.asStruct.ir.val!

    case .enum:
        return type.asEnum.ir.val!

    case .union:
        return type.asUnion.ir.val!

    case .tuple:
        let tuple = type.asTuple
        let types = tuple.types.map(canonicalize)
        switch types.count {
        case 1:
            return types[0]

        default:
            let type = StructType(elementTypes: types, isPacked: true)
            return type
        }

    case .pointer:
        let pointer = type.asPointer

        return PointerType(pointee: canonicalize(pointer.pointeeType))

    // these should not make it into IRGen (alternatively use these to gen typeinfo)
    case .polymorphic, .metatype, .file:
        fatalError()
    }
}
