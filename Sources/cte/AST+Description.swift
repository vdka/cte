
extension AstNode: CustomStringConvertible {

    var description: String {

        switch self.kind {
        case .invalid:
            return "<invalid>"

        case .empty:
            return ""

        case .list:

            return val.List.exprs
                .map({ $0.description })
                .joined(separator: ", ")

        case .identifier:
            return val.Identifier.name

        case .litString:
            return "\"" + val.StringLiteral.value + "\""

        case .litNumber:
            return val.NumberLiteral.value.description

        case .compiletime:
            return "$" + val.CompileTime.stmt.description

        case .function:

            let fn = val.Function
            let parameterList = fn.parameters
                .map({ $0.description })
                .joined(separator: ", ")

            let returnType = fn.returnType.description

            let body = fn.body.description
            
            return "fn" + "(" + parameterList + ") -> " + returnType + " " + body

        case .declaration:
            let d = val.Declaration
            let ident = d.identifier.description

            var value = ""
            if d.value.kind != .empty {
                value = " = " + d.value.description
            }

            if let type = d.type {
                return ident + ": " + type.description + value
            }
            return ident + " := " + d.value.description

        case .exprParen:
            return "(" + val.ExprParen.expr.description + ")"

        case .exprUnary:
            let u = val.ExprUnary
            let op = u.kind.description
            let expr = u.expr.description
            return op + expr

        case .exprBinary:
            let b = val.ExprBinary
            let op = b.kind.description
            let lhs = b.lhs.description
            let rhs = b.rhs.description
            return lhs + " " + op + " " + rhs

        case .exprCall:
            let call = val.ExprCall
            let callee = call.callee.description
            let arguments = call.arguments.map({ $0.description }).joined(separator: ", ")

            return callee + "(" + arguments + ")"

        case .stmtBlock:
            let block = val.StmtBlock
            let stmts = block.stmts.map({ "    " + $0.description }).joined(separator: "\n")

            return "{\n" + stmts + "\n}"

        case .stmtIf:
            let iff = val.StmtIf
            let cond = iff.condition.description
            let then = iff.thenStmt.description
            var elsé = ""
            if let elseStmt = iff.elseStmt {
                elsé = " else " + elseStmt.description
            }
            return "if " + cond + " " + then + elsé

        case .stmtReturn:
            let ret = val.StmtReturn
            return "return " + ret.value.description
        }
    }
}

