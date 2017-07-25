
extension AstNode: CustomStringConvertible {

    var description: String {

        switch self.kind {
        case .invalid:
            return "<invalid>"

        case .empty:
            return ""

        case .list:
            return asList.values.map({ $0.description }).joined(separator: ", ")

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

        case .compositeLiteral:
            let elements = asCompositeLiteral.elements.map({ $0.description }).joined(separator: ", ")
            return asCompositeLiteral.typeNode.description + " { " + elements + " }"

        case .compositeLiteralField:
            if let name = asCompositeLiteralField.identifier {
                return name.description + ": " + asCompositeLiteralField.value.description
            }
            return asCompositeLiteralField.value.description

        case .function, .polymorphicFunction:
            let fn = value as! CommonFunction
            let parameterList = fn.parameters
                .map({ $0.description })
                .joined(separator: ", ")

            let returnType = fn.returnTypes.map({ $0.description }).joined(separator: ", ")

            return "fn" + "(" + parameterList + ") -> " + returnType + " " + fn.body.description

        case .parameter:
            let param = asParameter
            return param.name.description + ": " + param.type.description

        case .functionType:
            let fn = asFunctionType
            let parameterList = fn.parameters
                .map({ $0.description })
                .joined(separator: ", ")

            let returnType = fn.returnTypes.map({ $0.description }).joined(separator: ", ")

            return "fn" + "(" + parameterList + ") -> " + returnType

        case .variadic:
            return ".." + asVariadic.type.description

        case .pointerType:
            return "*" + asPointerType.pointee.description

        case .structType:
            return "struct {\n" + asStructType.declarations.map({ "    " + $0.description }).joined(separator: "\n") + "\n}"

        case .unionType:
            return "union {\n" + asUnionType.declarations.map({ "    " + $0.description }).joined(separator: "\n") + "\n}"

        case .enumType:
            return "enum {\n" + asEnumType.cases.map({ "    " + $0.description }).joined(separator: "\n") + "\n}"

        case .compileTime:
            return "$" + asCompileTime.stmt.description

        case .declaration:
            let d = asDeclaration
            let names = d.names.map({ $0.description }).joined(separator: ", ")

            var values = ""
            if !d.values.isEmpty {
                values = (d.type == nil ? "= " : " = ") + d.values.map({ $0.description }).joined(separator: ", ")
            }

            if let type = d.type {
                return (d.isCompileTime ? "$" : "") + names + ": " + type.description + values
            }
            return names + (d.isCompileTime ? " :: " : " := ") + values

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
            let lvalue = a.lvalues.map({ $0.description }).joined(separator: ", ")
            let rvalue = a.rvalues.map({ $0.description }).joined(separator: ", ")
            return lvalue + " = " + rvalue

        case .call, .cast:
            let call = asCall
            let callee = call.callee.description
            let arguments = call.arguments.map({ $0.description }).joined(separator: ", ")

            return callee + "(" + arguments + ")"

        case .access, .structFieldAccess, .enumCaseAccess, .unionFieldAccess:
            return asAccess.aggregate.description + "." + asAccess.member.description

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
            let fór = asFor

            if fór.initializer == nil && fór.condition == nil && fór.step == nil {
                return "for " + fór.body.description
            }
            if let cond = fór.condition, fór.initializer == nil && fór.step == nil {
                return "for " + cond.description + fór.body.description
            }

            let initializer = fór.initializer?.description ?? ""
            let condition = fór.condition?.description ?? ""
            let post = fór.condition?.description ?? ""
            return "for " + initializer + "; " + condition + "; " + post + " " + fór.body.description

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
            return "return " + ret.values.map({ $0.description }).joined(separator: ", ")

        case .import:
            let imp = asImport
            return "#import " + imp.path + (imp.symbol?.description ?? (imp.includeSymbolsInParentScope ? " ." : ""))

        case .library:
            let lib = asLibrary
            return "#library " + lib.path + (lib.symbol?.description ?? "")

        case .foreign:
            let foreign = asForeign
            return "#foreign " + foreign.library.description + "\n" + foreign.stmt.description

        case .break:
            if let label = asBreak.label {
                return "break " + label.description
            }
            return "break"

        case .continue:
            if let label = asContinue.label {
                return "break " + label.description
            }
            return "continue"

        case .fallthrough:
            return "fallthrough"
        }
    }
}
