
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
            case .function:
                if decl.entity.type!.asFunction.needsSpecialization {

                    emitPolymorphicFunction(named: decl.entity.name, fn: decl.value.asCheckedPolymorphicFunction)
                } else {

                    decl.entity.value = emitFunction(named: decl.entity.name, decl.value.asCheckedFunction)
                }

            case .metatype:
                return

            default:
                let type = canonicalize(decl.entity.type!)
                let stackValue = builder.buildAlloca(type: type, name: decl.entity.name)
                decl.entity.value = stackValue

                guard decl.value != .empty else {
                    return
                }

                let value = emitExpr(node: decl.value)

                builder.buildStore(value, to: stackValue)

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

        if prefix.kind == .ampersand {
            return emitExpr(node: prefix.expr, returnAddress: true)
        }

        let expr = emitExpr(node: prefix.expr)

        switch prefix.kind {
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
            switch infix.kind {
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
            switch infix.kind {
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
        } else {
            callee = emitExpr(node: call.callee, returnAddress: true)
        }

        let args = call.arguments.map({ emitExpr(node: $0) })
        
        return builder.buildCall(callee, args: args)
    }

    func emitFunction(named name: String, _ fn: Checker.Function) -> Function {

        let function = builder.addFunction(name, type: canonicalize(fn.type) as! FunctionType)

        let entryBlock = function.appendBasicBlock(named: "entry")
        builder.positionAtEnd(of: entryBlock)
        defer {
            builder.positionAtEnd(of: mainFunction.entryBlock!)
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

            let entryBlock = function.appendBasicBlock(named: "entry")
            builder.positionAtEnd(of: entryBlock)
            defer {
                builder.positionAtEnd(of: mainFunction.entryBlock!)
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
        // strip specialized paramters.
        for param in fn.params.filter({ !$0.flags.contains(.ct) }) {

            paramTypes.append(canonicalize(param.type!))
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

