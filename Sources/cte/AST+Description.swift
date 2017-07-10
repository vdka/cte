
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

        case .variadic:
            return ".." + asVariadic.type.description

        case .pointerType:
            return "*" + asPointerType.pointee.description

        case .compileTime:
            return "$" + asCompileTime.stmt.description

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
            let prefix = asPrefix
            let op = prefix.token.description
            let expr = prefix.expr.description
            return op + expr

        case .infix:
            let infix = asInfix
            let op = infix.token.description
            let lhs = infix.lhs.description
            let rhs = infix.rhs.description
            return lhs + " " + op + " " + rhs

        case .assign:
            let a = asAssign
            return a.lvalue.description + " = " + a.rvalue.description

        case .call, .cast:
            let call = asCall
            let callee = call.callee.description
            let arguments = call.arguments.map({ $0.description }).joined(separator: ", ")

            return callee + "(" + arguments + ")"

        case .memberAccess:
            return asMemberAccess.aggregate.description + "." + asMemberAccess.member.description

        case .block:
            let block = asBlock
            let stmts = block.stmts.map({ "    " + $0.description }).joined(separator: "\n")

            return "{\n" + stmts + "\n}"

        case .if:
            let íf = asIf
            let cond = íf.condition.description
            let then = íf.thenStmt.description
            var elsé = ""
            if let elseStmt = íf.elseStmt {
                elsé = " else " + elseStmt.description
            }
            return "if " + cond + " " + then + elsé

        case .for:
            //TODO(Brett): finishs
            return "for"

        case .switch:
            let świtch = asSwitch

            let subject = świtch.subject?.description ?? ""
            let cases = świtch.cases.map({ $0.description }).joined(separator: "\n")
            return "switch \(subject){\n" + cases + "\n}"

        case .case:
            let ćase = asCase

            return "case \(ćase.condition?.description ?? ""):"
        case .return:
            let ret = asReturn
            return "return " + ret.value.description

        case .import:
            let imp = asImport
            return "#import " + imp.path + (imp.symbol?.description ?? (imp.includeSymbolsInParentScope ? " ." : ""))

        case .library:
            let lib = asLibrary
            return "#library " + lib.path + (lib.symbol?.description ?? "")

        case .foreign:
            let foreign = asForeign
            return "#foreign " + foreign.library.description + "\n" + foreign.stmt.description
        }
    }
}
