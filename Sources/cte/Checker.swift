
struct Checker {
    var nodes: [AstNode]

    var currentScope: Scope = Scope(parent: Scope.global)
    var currentExpectedReturnType: Type? = nil

    var info = Info()

    struct Info {
        var scopes: [AstNode: Scope] = [:]
    }

    init(nodes: [AstNode]) {
        self.nodes = nodes
    }
}


extension Checker {

    mutating func check() -> Info {

        for node in nodes {
            check(node: node)
        }

        return info
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

        case .block:
            for node in node.asBlock.stmts {
                check(node: node)
            }

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
                reportError("Cannot convert type '\(type)' to expected type '\(ret)'", at: ret.value)
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

            info.scopes[node] = currentScope

            var paramTypes: [Type] = []
            for param in fn.parameters {
                assert(param.kind == .declaration)

                check(node: param)

                let entity = currentScope.members.last!

                paramTypes.append(entity.type!)
            }

            let returnType = checkExpr(node: fn.returnType)

            let prevExpectedReturnType = currentExpectedReturnType
            currentExpectedReturnType = returnType
            defer {
                currentExpectedReturnType = prevExpectedReturnType
            }

            check(node: fn.body)

            let functionType = Type.Function(paramTypes: paramTypes, returnType: returnType)

            return Type(value: functionType, entity: Entity.anonymous)

        case .paren:
            return checkExpr(node: node.asParen.expr)

        case .prefix:
            let prefix = node.asPrefix
            let exprType = checkExpr(node: prefix.expr)
            guard exprType == Type.number else {
                reportError("Prefix operator '\(prefix.kind)', is invalid on type '\(exprType)'", at: prefix.expr)
                return Type.invalid
            }
            return exprType

        case .infix:
            let infix = node.asInfix
            let lhsType = checkExpr(node: infix.lhs)
            let rhsType = checkExpr(node: infix.rhs)
            guard lhsType == Type.number, lhsType == rhsType else {
                reportError("Infix operator '\(infix.kind)', is only valid on 'number' types", at: node)
                return Type.invalid
            }

            switch infix.kind {
            case .lt, .lte, .gt, .gte:
                return Type.bool

            case .plus, .minus:
                return Type.number

            default:
                fatalError()
            }

        case .call:
            let call = node.asCall
            let calleeType = checkExpr(node: call.callee)
            guard case .function = calleeType.kind else {
                reportError("Cannot call value of non-function type '\(calleeType)'", at: node)
                return Type.invalid
            }

            for (arg, expected) in zip(call.arguments, calleeType.asFunction.paramTypes) {

                let argType = checkExpr(node: arg)

                guard argType == expected else {
                    reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expected)'", at: arg)
                    continue
                }
            }

            return calleeType.asFunction.returnType

        default:
            fatalError()
        }
    }
}


extension Checker {

    struct Empty: AstNodeValue {
        static let astKind = AstKind.empty
    }

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

        let type: Type
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
        let type: Type
    }

    struct Block: AstNodeValue {
        static let astKind = AstKind.block

        let stmts: [AstNode]
        let scope: Scope
    }

    struct If: AstNodeValue {
        static let astKind = AstKind.if

        let condition: AstNode
        let thenStmt: AstNode
        let elseStmt: AstNode?
    }

    struct Return: AstNodeValue {
        static let astKind = AstKind.return

        let value: AstNode
    }
}

















