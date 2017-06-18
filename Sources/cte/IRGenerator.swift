
import LLVM

struct IRGenerator {

    var nodes: [AstNode]

    var module: Module
    var builder: IRBuilder

    var mainFunction: Function

    init(forModuleNamed name: String, nodes: [AstNode]) {
        self.nodes = nodes

        self.module = Module(name: name)
        self.builder = IRBuilder(module: module)

        let mainType = FunctionType(argTypes: [], returnType: IntType.int32)
        self.mainFunction = builder.addFunction("main", type: mainType)

        let entryBlock = mainFunction.appendBasicBlock(named: "entry")

        builder.positionAtEnd(of: entryBlock)
    }

    func generate() {

        for node in nodes {
            emit(node: node)
        }

        builder.positionAtEnd(of: mainFunction.entryBlock!)
        builder.buildRet(IntType.int32.constant(0))
    }

    func emit(node: AstNode) {

        switch node.kind {
        case .declaration:
            let decl = node.asCheckedDeclaration

            if decl.entity.type!.kind == .metatype {
                return
            }

            switch decl.entity.type!.kind {
            case .builtin:
                let type = decl.entity.type!.canonicalize()
                let stackValue = builder.buildAlloca(type: type, name: decl.entity.name)
                decl.entity.value = stackValue

                guard decl.value != .empty else {
                    return
                }

                let value = emitExpr(node: decl.value)

                builder.buildStore(value, to: stackValue)

            case .function:
                if decl.entity.type!.asFunction.needsSpecialization {

                    decl.entity.specializations = emitPolymorphicFunction(named: decl.entity.name, fn: decl.value.asCheckedPolymorphicFunction)
                } else {

                    decl.entity.value = emitFunction(named: decl.entity.name, decl.value.asCheckedFunction)
                }

            case .metatype:
                return
            }

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

        default:
            fatalError()
        }
    }

    func emitExpr(node: AstNode, returnAddress: Bool = false) -> IRValue {
        if returnAddress {
            assert(node.kind == .identifier)
        }

        switch node.kind {
        case .litNumber:
            return FloatType.double.constant(node.asNumberLiteral.value)

        case .litString:
            return builder.buildGlobalStringPtr(node.asStringLiteral.value)

        case .identifier:
            let ident = node.asCheckedIdentifier
            let stackValue = ident.entity.value!
            if returnAddress {
                return stackValue
            }
            return builder.buildLoad(stackValue)

        case .paren:
            return emitExpr(node: node.asCheckedParen.expr)

        case .prefix:
            return emitPrefix(node.asCheckedPrefix)

        case .infix:
            return emitInfix(node.asCheckedInfix)

        case .call:
            return emitCall(node.asCheckedCall)

        default:
            fatalError()
        }
    }

    func emitPrefix(_ prefix: Checker.Prefix) -> IRValue {

        let expr = emitExpr(node: prefix.expr)

        switch prefix.kind {
        case .plus:
            return expr

        case .minus:
            return builder.buildNeg(expr)

        default:
            fatalError()
        }
    }

    func emitInfix(_ infix: Checker.Infix) -> IRValue {

        let lhs = emitExpr(node: infix.lhs)
        let rhs = emitExpr(node: infix.rhs)

        switch infix.kind {
        case .plus:
            return builder.buildAdd(lhs, rhs)

        case .minus:
            return builder.buildSub(lhs, rhs)

        case .lt:
            return builder.buildFCmp(lhs, rhs, .orderedLessThan)

        case .lte:
            return builder.buildFCmp(lhs, rhs, .orderedLessThanOrEqual)

        case .gt:
            return builder.buildFCmp(lhs, rhs, .orderedGreaterThan)

        case .gte:
            return builder.buildFCmp(lhs, rhs, .orderedGreaterThanOrEqual)

        default:
            fatalError()
        }
    }

    func emitCall(_ call: Checker.Call) -> IRValue {

        if call.isSpecialized {
            return emitPolymorphicCall(call)
        }

        let callee = emitExpr(node: call.callee, returnAddress: true)
        let args = call.arguments.map({ emitExpr(node: $0) })
        
        return builder.buildCall(callee, args: args)
    }

    func emitPolymorphicCall(_ call: Checker.Call) -> IRValue {

        let calleeEntity = call.callee.asCheckedIdentifier.entity
        let calleeType = calleeEntity.type!

        var args: [IRValue] = []
        var nameSuffix = ""
        for (arg, param) in zip(call.arguments, calleeType.asFunction.params) {

            if param.flags.contains(.ct) {
                // FIXME: HACK find way to determine type without emitting anything
                let type = arg.asCheckedIdentifier.entity.type!
                nameSuffix.append(type.description)
            } else {
                let irArg = emitExpr(node: arg)
                args.append(irArg)
            }
        }

        let fnName = calleeEntity.entity.name + nameSuffix // TODO(vdka): Turn specializations into anon entities.
        let function = calleeEntity.specializations!.first(where: { $0.name == fnName })!

        let function = module.function(named: fnName)!

        return builder.buildCall(function, args: args)
    }

    func emitFunction(named name: String, _ fn: Checker.Function) -> Function {

        let function = builder.addFunction(name, type: fn.type.canonicalize() as! FunctionType)

        let entryBlock = function.appendBasicBlock(named: "entry")
        builder.positionAtEnd(of: entryBlock)
        defer {
            builder.positionAtEnd(of: mainFunction.entryBlock!)
        }

        for (param, var irParam) in zip(fn.parameters, function.parameters) {

            emit(node: param)

            let entity = param.asCheckedDeclaration.entity
            irParam.name = entity.name

            builder.buildStore(irParam, to: entity.value!)
        }

        emit(node: fn.body)

        return function
    }

    func emitPolymorphicFunction(named name: String, fn: Checker.PolymorphicFunction) -> [Function] {

        var specializations: [Function] = []
        for specialization in fn.specializations {

            let nameSuffix = specialization.specializedTypes.reduce("", { $0.0 + "$" + $0.1.description })

            let function = builder.addFunction(name + nameSuffix, type: specialization.strippedType.canonicalize() as! FunctionType)

            let entryBlock = function.appendBasicBlock(named: "entry")
            builder.positionAtEnd(of: entryBlock)
            defer {
                builder.positionAtEnd(of: mainFunction.entryBlock!)
            }

            let runtimeParameters = zip(fn.type.asFunction.params, fn.parameters).filter({ !$0.0.flags.contains(.ct) }).map({ $0.1 })

            for (param, var irParam) in zip(runtimeParameters, function.parameters) {

                emit(node: param)

                let entity = param.asCheckedDeclaration.entity
                irParam.name = entity.name

                builder.buildStore(irParam, to: entity.value!)
            }

            emit(node: fn.body)

            specializations.append(function)
        }

        return specializations
    }
}

extension Type {

    func canonicalize() -> IRType {

        switch self.kind {
        case .builtin:
            if self == Type.void {
                return VoidType()
            }

            if self == Type.bool {
                return IntType.int1
            }

            if self == Type.type {
                fatalError()
            }

            if self == Type.string {
                return PointerType.toVoid
            }

            if self == Type.number {
                return FloatType.double
            }

            fatalError()

        case .function:
            let fn = self.asFunction

            var paramTypes: [IRType] = []
            // strip specialized paramters.
            for param in fn.params.filter({ !$0.flags.contains(.ct) }) {

                paramTypes.append(param.type!.canonicalize())
            }

            let retType = fn.returnType.canonicalize()

            return FunctionType(argTypes: paramTypes, returnType: retType)

        case .metatype:
            fatalError() // these should not make it into IRGen (alternatively use these to gen typeinfo)
        }
    }
}
