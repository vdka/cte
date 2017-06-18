
extension AstNode: CustomStringConvertible {

    var description: String {

        switch self.kind {
        case .invalid:
            return "<invalid>"

        case .empty:
            return ""

        case .identifier:
            return asIdentifier.name

        case .litString:
            return "\"" + asStringLiteral.value + "\""

        case .litNumber:
            return asNumberLiteral.value.description

        case .function, .polymorphicFunction:

            let fn = asFunction
            let parameterList = fn.parameters
                .map({ $0.description })
                .joined(separator: ", ")

            let returnType = fn.returnType.description

            let body = fn.body.description
            
            return "fn" + "(" + parameterList + ") -> " + returnType + " " + body

        case .declaration:
            let d = asDeclaration
            let ident = d.identifier.description

            var value = ""
            if d.value.kind != .empty {
                value = " = " + d.value.description
            }

            if let type = d.type {
                return (d.isCompileTime ? "$" : "") + ident + ": " + type.description + value
            }
            return ident + (d.isCompileTime ? " :: " : " := ") + d.value.description

        case .paren:
            return "(" + asParen.expr.description + ")"

        case .prefix:
            let u = asPrefix
            let op = u.kind.description
            let expr = u.expr.description
            return op + expr

        case .infix:
            let b = asInfix
            let op = b.kind.description
            let lhs = b.lhs.description
            let rhs = b.rhs.description
            return lhs + " " + op + " " + rhs

        case .call:
            let call = asCall
            let callee = call.callee.description
            let arguments = call.arguments.map({ $0.description }).joined(separator: ", ")

            return callee + "(" + arguments + ")"

        case .block:
            let block = asBlock
            let stmts = block.stmts.map({ "    " + $0.description }).joined(separator: "\n")

            return "{\n" + stmts + "\n}"

        case .if:
            let iff = asIf
            let cond = iff.condition.description
            let then = iff.thenStmt.description
            var elsé = ""
            if let elseStmt = iff.elseStmt {
                elsé = " else " + elseStmt.description
            }
            return "if " + cond + " " + then + elsé

        case .return:
            let ret = asReturn
            return "return " + ret.value.description
        }
    }
}

