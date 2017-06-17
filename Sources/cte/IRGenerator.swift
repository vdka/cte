
import cllvm

struct IRGenerator {

    var nodes: [AstNode]
    var info: Checker.Info

    var module: LLVMModuleRef
    var builder: LLVMBuilderRef

    var mainFunction: LLVMValueRef

    init(forModuleNamed name: String, nodes: [AstNode], info: Checker.Info) {
        self.nodes = nodes
        self.info = info

        self.module = LLVMModuleCreateWithName(name)
        self.builder = LLVMCreateBuilder()

        let mainType = LLVMFunctionType(LLVMIntType(32), nil, 0, 0)
        self.mainFunction = LLVMAddFunction(module, "main", mainType)
        LLVMPositionBuilderAtEnd(builder, LLVMGetEntryBasicBlock(mainFunction))
    }

    func generate() -> LLVMModuleRef {

//        for node in nodes {
//            emit(node: node)
//        }

        fatalError()
    }

    /*
    func emit(node: AstNode) {

        switch node.kind {
        case .declaration:


        }
    }

    func emitExpr(node: AstNode) -> LLVMValueRef {

    }
    */
}

extension Type {

    func canonicalize() -> LLVMTypeRef {

        switch self.kind {
        case .builtin:
            if self == Type.void {
                return LLVMVoidType()
            }

            if self == Type.bool {
                return LLVMIntType(1)
            }

            if self == Type.type {
                fatalError()
            }

            if self == Type.string {
                return LLVMPointerType(LLVMInt8Type(), 0)
            }

            if self == Type.number {
                return LLVMDoubleType()
            }

            fatalError()

        case .function:
            let fn = self.asFunction

            var paramTypes = fn.paramTypes.map({ $0.canonicalize() as Optional })
            let retType = fn.returnType.canonicalize()

            return paramTypes.withUnsafeMutableBufferPointer {
                return LLVMFunctionType(retType, $0.baseAddress!, numericCast(paramTypes.count), 0)
            }
        }
    }
}
