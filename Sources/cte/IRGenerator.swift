
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
        case .comment, .import, .library:
            return

        case .declaration:
            let decl = node.asCheckedDeclaration

            guard decl.entity.type!.kind != .metatype else {
                return
            }

            guard (decl.value.kind != .polymorphicFunction && decl.value.kind != .function) || decl.isForeign else {
                decl.entity.value = emitExpr(node: decl.value, name: decl.entity.name)
                return
            }

            let type = canonicalize(decl.entity.type!)

            if decl.isForeign {
                let name = decl.linkName ?? decl.identifier.asIdentifier.name
                if let type = type as? FunctionType {
                    let function = builder.addFunction(name, type: type)
                    decl.entity.value = function
                    return
                }

                var global = builder.addGlobal(name, type: type)
                global.isExternallyInitialized = true
                decl.entity.value = global
                return
            }

            if decl.entity.flags.contains(.ct) {
                let value = emitExpr(node: decl.value)
                var globalValue = builder.addGlobal(decl.entity.name, initializer: value)
                globalValue.isGlobalConstant = true
                decl.entity.value = globalValue
                return
            }

            if let file = decl.entity.owningScope.file, !file.isInitialFile {
                let value = emitExpr(node: decl.value)
                let globalValue = builder.addGlobal(decl.entity.name, initializer: value)
                decl.entity.value = globalValue
                return
            }

            if options.contains(.emitIr) {
                if let endOfAlloca = builder.insertBlock!.instructions.first(where: { !$0.isAAllocaInst }) {
                    builder.position(endOfAlloca, block: builder.insertBlock!)
                }
            }

            let stackValue = builder.buildAlloca(type: type, name: decl.entity.name)

            if options.contains(.emitIr) {
                builder.positionAtEnd(of: builder.insertBlock!)
            }

            decl.entity.value = stackValue

            guard decl.value != .empty else {
                return
            }

            let value = emitExpr(node: decl.value, name: decl.entity.name)

            builder.buildStore(value, to: stackValue)

        case .assign:
            let assign = node.asCheckedAssign

            let lvalue = emitExpr(node: assign.lvalue, returnAddress: true)
            let rvalue = emitExpr(node: assign.rvalue)
            builder.buildStore(rvalue, to: lvalue)

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

        case .return:
            let ret = node.asReturn
            let val = emitExpr(node: ret.value)
            builder.buildRet(val)

        case .switch:
            let świtch = node.asCheckedSwitch
            if świtch.subject == nil {
                emitBooleanesqueSwitch(świtch)
            } else {
                emitSwitch(świtch)
            }

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

            let entity = param.asCheckedDeclaration.entity
            irParam.name = entity.name

            emit(node: param)

            builder.buildStore(irParam, to: entity.value!)
        }

        emit(node: fn.body)

        return function
    }

    func emitPolymorphicFunction(named name: String, fn: Checker.PolymorphicFunction) {

        for specialization in fn.specializations {

            let fn = specialization.fnNode.asCheckedFunction

            let nameSuffix = specialization.specializedTypes.reduce("", { $0 + "$" + $1.asMetatype.instanceType.description })

            let function = builder.addFunction(name + nameSuffix, type: canonicalize(specialization.strippedType) as! FunctionType)

            let lastBlock = builder.insertBlock

            let entryBlock = function.appendBasicBlock(named: "entry")
            builder.positionAtEnd(of: entryBlock)
            defer {
                if let lastBlock = lastBlock {
                    builder.positionAtEnd(of: lastBlock)
                }
            }

            for (param, var irParam) in zip(fn.parameters, function.parameters) {

                let entity = param.asCheckedDeclaration.entity
                irParam.name = entity.name

                emit(node: param)

                builder.buildStore(irParam, to: entity.value!)
            }

            emit(node: fn.body)

            specialization.llvm = function
        }
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
            // TODO(Brett): update scope for case body
            for stmt in ćase.body {
                emit(node: stmt)
            }

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
        unimplemented("IRGen for booleanesque switch")
    }
}

func canonicalize(_ type: Type) -> IRType {

    switch type.kind {
    case .void:
        return VoidType()

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
        for param in fn.params {

            paramTypes.append(canonicalize(param))
        }

        let retType = canonicalize(fn.returnType)

        return FunctionType(argTypes: paramTypes, returnType: retType)

    case .pointer:
        let pointer = type.asPointer

        return PointerType(pointee: canonicalize(pointer.pointeeType))

    case .metatype:
        fatalError() // these should not make it into IRGen (alternatively use these to gen typeinfo)
    }
}
