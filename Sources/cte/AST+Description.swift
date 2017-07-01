
extension AstNode: CustomStringConvertible {

    var description: String {

        switch self.kind {
        case .invalid:
            return "<invalid>"

        case .empty:
            return ""

        case .comment:
            return "//" + asComment.comment

        case .identifier:
            return asIdentifier.name

        case .litString:
            return "\"" + asStringLiteral.value + "\""

        case .litFloat:
            return asFloatLiteral.value.description

        case .litInteger:
            return asIntegerLiteral.value.description

        case .function, .polymorphicFunction:

            let fn = asFunction
            let parameterList = fn.parameters
                .map({ $0.description })
                .joined(separator: ", ")

            let returnType = fn.returnType.description

            return "fn" + "(" + parameterList + ") -> " + returnType + " " + fn.body.description

        case .functionType:

            let fn = asFunctionType
            let parameterList = fn.parameters
                .map({ $0.description })
                .joined(separator: ", ")

            let returnType = fn.returnType.description

            return "fn" + "(" + parameterList + ") -> " + returnType

        case .pointerType:
            return "*" + asPointerType.pointee.description

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

        case .assign:
            let a = asAssign
            return a.lvalue.description + " = " + a.rvalue.description

        case .call, .cast:
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

