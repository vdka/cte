
import LLVM

struct IRGenerator {

    var file: SourceFile

    var module: Module
    var builder: IRBuilder

    var function: Function?

    init(forModule module: Module, file: SourceFile) {
        self.file = file

        self.module = module
        self.builder = IRBuilder(module: module)

        let mainType = FunctionType(argTypes: [], returnType: IntType.int32)
        if file.isInitialFile {
            // this is the file the compiler has been invoked upon
            let mainFunction = builder.addFunction("main", type: mainType)
            let entryBlock = mainFunction.appendBasicBlock(named: "entry")
            builder.positionAtEnd(of: entryBlock)
            self.function = mainFunction
        }
    }

    func generate() {

        for node in file.nodes {
            emit(node: node)
        }

        if file.isInitialFile {
            builder.positionAtEnd(of: function!.entryBlock!)
            builder.buildRet(IntType.int32.constant(0))
        }
    }

    func emit(node: AstNode) {

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
                let aggregate = emitCall(decl.values[0].asCheckedCall)

                for (index, entity) in decl.entities.enumerated() {
                    let rvalue = builder.buildStructGEP(aggregate, index: index)
                    builder.buildStore(rvalue, to: entity.value!)
                }

                return
            }

            assert(decl.entities.count == decl.values.count)
            for (entity, value) in zip(decl.entities, decl.values)
                where !entity.type!.isMetatype
            {
                let type = canonicalize(entity.type!)

                if decl.isForeign {
                    assert(decl.names.count == 1 && decl.entities.count == 1)
                    let name = decl.linkName ?? entity.name
                    if let type = type as? FunctionType {
                        let function = builder.addFunction(name, type: type)
                        entity.value = function
                        return
                    }

                    var global = builder.addGlobal(name, type: type)
                    global.isExternallyInitialized = true
                    entity.value = global
                    return
                }

                if entity.flags.contains(.compileTime) {
                    let value = emitExpr(node: value)
                    var globalValue = builder.addGlobal(entity.name, initializer: value)
                    globalValue.isGlobalConstant = true
                    entity.value = globalValue
                    return
                }

                if let file = entity.owningScope.file, !file.isInitialFile {
                    let value = emitExpr(node: value)
                    let globalValue = builder.addGlobal(entity.name, initializer: value)
                    entity.value = globalValue
                    return
                }

                if options.contains(.emitIr) {

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

                if options.contains(.emitIr) {
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
            let assign = node.asCheckedAssign

            if assign.rvalueIsCall && assign.lvalues.count > 1 {
                let aggregate = emitCall(assign.rvalues[0].asCheckedCall)

                for (index, lvalue) in assign.lvalues.enumerated() {
                    let lvalueAddress = emitExpr(node: lvalue, returnAddress: true)
                    let rvalue = builder.buildStructGEP(aggregate, index: index)
                    builder.buildStore(rvalue, to: lvalueAddress)
                }
                return
            }

            var rvalues: [IRValue] = []
            for rvalue in assign.rvalues {
                let rvalue = emitExpr(node: rvalue)
                rvalues.append(rvalue)
            }

            for (lvalue, rvalue) in zip(assign.lvalues, rvalues) {
                let lvalueAddress = emitExpr(node: lvalue, returnAddress: true)
                builder.buildStore(rvalue, to: lvalueAddress)
            }

        case .parameter:
            let param = node.asCheckedParameter

            let type = canonicalize(param.entity.type!)

            if options.contains(.emitIr) {

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

            if options.contains(.emitIr) {
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
            let fór = node.asFor
            emitFor(fór)

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
            let świtch = node.asCheckedSwitch
            if świtch.subject == nil {
                emitBooleanesqueSwitch(świtch)
            } else {
                emitSwitch(świtch)
            }

        case .call:
            emitCall(node.asCheckedCall)

        default:
            fatalError()
        }
    }

    func emitExpr(node: AstNode, returnAddress: Bool = false, name: String = "") -> IRValue {

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

        case .call:
            return emitCall(node.asCheckedCall)

        case .cast:
            let cast = node.asCheckedCast
            let val = emitExpr(node: cast.arguments.first!)
            return builder.buildCast(cast.cast, value: val, type: canonicalize(cast.type))

        case .memberAccess:
            let access = node.asCheckedMemberAccess
            if access.entity.owningScope.isFile {
                if access.entity.type!.isFunction {
                    return access.entity.value!
                }
                return builder.buildLoad(access.entity.value!)
            }
            fatalError("Only file entities have child scopes currently")

        default:
            fatalError()
        }
    }

    func emitPrefix(_ prefix: Checker.Prefix) -> IRValue {

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

        default:
            fatalError()
        }
    }

    func emitInfix(_ infix: Checker.Infix) -> IRValue {

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
            default:
                fatalError()
            }
            return builder.buildFCmp(lhs, rhs, pred)

        default:
            return builder.buildBinaryOperation(infix.op, lhs, rhs)
        }
    }

    @discardableResult
    func emitCall(_ call: Checker.Call) -> IRValue {

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

    func emitFunction(named name: String, _ fn: Checker.Function) -> Function {

        let function = builder.addFunction(name, type: canonicalize(fn.type) as! FunctionType)

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

        emit(node: fn.body)

        return function
    }

    func emitPolymorphicFunction(named name: String, fn: Checker.PolymorphicFunction) {

        for specialization in fn.specializations {
            let fn = specialization.generatedFunctionNode.asCheckedFunction

            let suffix = specialization.specializedTypes.reduce("", { $0 + "$" + $1.asMetatype.instanceType.description })
            specialization.llvm = emitFunction(named: name + suffix, fn)
        }
    }

    func emitFor(_ fór: CommonFor) {
        let currentFunc = builder.currentFunction!

        var loopBody: BasicBlock
        var loopPost: BasicBlock
        var loopCond: BasicBlock?
        var loopStep: BasicBlock?

        if let initializer = fór.initializer {
            emit(node: initializer)
        }

        if let condition = fór.condition {
            loopCond = currentFunc.appendBasicBlock(named: "for.cond")
            if fór.step != nil {
                loopStep = currentFunc.appendBasicBlock(named: "for.step")
            }

            loopBody = currentFunc.appendBasicBlock(named: "for.body")
            loopPost = currentFunc.appendBasicBlock(named: "for.post")

            builder.buildBr(loopCond!)
            builder.positionAtEnd(of: loopCond!)

            let condVal = emitExpr(node: condition)
            builder.buildCondBr(condition: condVal, then: loopBody, else: loopPost)
        } else {
            if fór.step != nil {
                loopStep = currentFunc.appendBasicBlock(named: "for.step")
            }

            loopBody = currentFunc.appendBasicBlock(named: "for.body")
            loopPost = currentFunc.appendBasicBlock(named: "for.post")

            builder.buildBr(loopBody)
        }

        //TODO(Brett): escape points
        builder.positionAtEnd(of: loopBody)

        emit(node: fór.body)

        let hasJump = builder.insertBlock?.terminator != nil

        if let step = fór.step {
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

    func emitSwitch(_ świtch: Checker.Switch) {
        let subject = świtch.subject!

        let switchLn = subject.tokens.first!.start.line

        let currentFunc = builder.currentFunction!
        let currentBlock = builder.insertBlock!

        let defaultBlock = currentFunc.appendBasicBlock(named: "switch.default.ln.\(switchLn)")
        let postBlock = currentFunc.appendBasicBlock(named: "switch.post.ln.\(switchLn)")

        // TODO(Brett): escape points
        builder.positionAtEnd(of: currentBlock)
        let value = emitExpr(node: subject)

        var caseBlocks: [BasicBlock] = []
        var constants: [IRValue] = []

        for ćase in świtch.cases {
            let ćase = ćase.asCheckedCase

            let block: BasicBlock

            if let match = ćase.condition {
                constants.append(emitExpr(node: match))
                let ln = match.tokens.first!.start.line
                block = currentFunc.appendBasicBlock(named: "switch.case.ln.\(ln)")
                caseBlocks.append(block)
            } else {
                block = defaultBlock
            }

            builder.positionAtEnd(of: block)

            emit(node: ćase.block)

            if builder.insertBlock!.terminator == nil {
                builder.buildBr(postBlock)
            }
            assert(block.terminator != nil)

            builder.positionAtEnd(of: currentBlock)
        }

        let switchPtr = builder.buildSwitch(value, else: defaultBlock, caseCount: constants.count)
        for (constant, block) in zip(constants, caseBlocks) {
            switchPtr.addCase(constant, block)
        }

        builder.positionAtEnd(of: postBlock)
    }

    func emitBooleanesqueSwitch(_ świtch: Checker.Switch) {
        let switchLn = świtch.cases.first!.tokens.first!.start.line

        let currentFunc = builder.currentFunction!
        let currentBlock = builder.insertBlock!

        let postBlock = currentFunc.appendBasicBlock(named: "bswitch.post.ln.\(switchLn)")

        // TODO(Brett): escape points
        var condBlocks: [BasicBlock] = []
        var thenBlocks: [BasicBlock] = []

        for i in 0..<świtch.cases.count {
            let ln = świtch.cases[i].tokens.first!.start.line
            condBlocks.append(currentFunc.appendBasicBlock(named: "bswitch.cond.ln.\(ln)"))
            thenBlocks.append(currentFunc.appendBasicBlock(named: "bswitch.then.ln.\(ln)"))
        }

        builder.positionAtEnd(of: currentBlock)

        for (i, caseStmt) in świtch.cases.enumerated() {
            let caseStmt = caseStmt.asCheckedCase

            let nextCondBlock = condBlocks[safe: i+1] ?? postBlock
            let condBlock: BasicBlock

            if i == 0 {
                // the first conditional needs to be in the starting block
                condBlock = currentBlock
                condBlocks[i].removeFromParent()
            } else {
                condBlock = condBlocks[i]
            }

            let thenBlock = thenBlocks[i]

            builder.positionAtEnd(of: condBlock)

            if let match = caseStmt.condition {
                let cond = emitExpr(node: match)
                builder.buildCondBr(condition: cond, then: thenBlock, else: nextCondBlock)
            } else {
                // this is the default case. Will just jump to the `then` block
                builder.buildBr(thenBlock)
            }

            builder.positionAtEnd(of: thenBlock)
            emit(node: caseStmt.block)

            builder.positionAtEnd(of: thenBlock)
            if thenBlock.terminator == nil {
                builder.buildBr(postBlock)
            }
        }

        postBlock.moveAfter(thenBlocks.last!)
        builder.positionAtEnd(of: postBlock)
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
                paramTypes.append(canonicalize(param))
            }
        }

        let retType = canonicalize(fn.returnType)

        return FunctionType(argTypes: paramTypes, returnType: retType, isVarArg: fn.isCVariadic)

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
