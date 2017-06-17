
struct Checker {
    var nodes: [AstNode]
    var currentScope: Scope = Scope()
    var info = Info()

    struct Info {
        var scopes: [AstNode: Scope] = [:]
    }

    init(nodes: [AstNode]) {
        self.nodes = nodes
    }
}


extension Checker {

    func check() -> Info {

        for node in nodes {
            check(node: node)
        }

        return info
    }

    func check(node: AstNode) {

        switch node.kind {
        case .empty:
            return

        case .identifier, .exprCall, .exprParen, .exprUnary, .exprBinary:
            let type = checkExpr(node: node)
            reportError("Expression of type '\(type)' is unused", at: node)

        default:
            break
        }
    }

    func checkExpr(node: AstNode) -> Type {

        switch node.kind {
        case .identifier:
            let ident = node.val.Identifier.name
            guard let entity = self.currentScope.lookup(ident) else {
                reportError("Use of undefined identifier '\(ident)'", at: node)
                return Type.invalid
            }
            return entity.type!

        case .litString:
            return Type.string

        case .litNumber:
            return Type.number

        default:
            fatalError()
        }
    }
}
