// Generated using Sourcery 0.7.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


extension AstValue {

    func copy() -> AstValue {
        switch self {

        case let value as AstNode.Assign:
            return AstNode.Assign(
                lvalue: value.lvalue.copy(),
                rvalue: value.rvalue.copy()
        )

        case let value as AstNode.Block:
            return AstNode.Block(
                stmts: value.stmts.map({ $0.copy() })
        )

        case let value as AstNode.Call:
            return AstNode.Call(
                callee: value.callee.copy(),
                arguments: value.arguments.map({ $0.copy() })
        )

        case let value as AstNode.Comment:
            return AstNode.Comment(
                comment: value.comment
        )

        case let value as AstNode.Declaration:
            return AstNode.Declaration(
                identifier: value.identifier.copy(),
                type: value.type?.copy(),
                value: value.value.copy(),
                isCompileTime: value.isCompileTime
        )

        case is AstNode.Empty:
            return AstNode.Empty()

        case let value as AstNode.FloatLiteral:
            return AstNode.FloatLiteral(
                value: value.value
        )

        case let value as AstNode.Function:
            return AstNode.Function(
                parameters: value.parameters.map({ $0.copy() }),
                returnType: value.returnType.copy(),
                body: value.body.copy()
        )

        case let value as AstNode.FunctionType:
            return AstNode.FunctionType(
                parameters: value.parameters.map({ $0.copy() }),
                returnType: value.returnType.copy()
        )

        case let value as AstNode.Identifier:
            return AstNode.Identifier(
                name: value.name
        )

        case let value as AstNode.If:
            return AstNode.If(
                condition: value.condition.copy(),
                thenStmt: value.thenStmt.copy(),
                elseStmt: value.elseStmt?.copy()
        )

        case let value as AstNode.Infix:
            return AstNode.Infix(
                kind: value.kind,
                lhs: value.lhs.copy(),
                rhs: value.rhs.copy()
        )

        case let value as AstNode.IntegerLiteral:
            return AstNode.IntegerLiteral(
                value: value.value
        )

        case is AstNode.Invalid:
            return AstNode.Invalid()

        case let value as AstNode.Paren:
            return AstNode.Paren(
                expr: value.expr.copy()
        )

        case let value as AstNode.PointerType:
            return AstNode.PointerType(
                pointee: value.pointee.copy()
        )

        case let value as AstNode.Prefix:
            return AstNode.Prefix(
                kind: value.kind,
                expr: value.expr.copy()
        )

        case let value as AstNode.Return:
            return AstNode.Return(
                value: value.value.copy()
        )

        case let value as AstNode.StringLiteral:
            return AstNode.StringLiteral(
                value: value.value
        )

        case let value as Checker.Assign:
            return Checker.Assign(
                lvalue: value.lvalue.copy(),
                rvalue: value.rvalue.copy()
        )

        case let value as Checker.Block:
            return Checker.Block(
                stmts: value.stmts.map({ $0.copy() }),
                scope: value.scope.copy()
        )

        case let value as Checker.Call:
            return Checker.Call(
                callee: value.callee.copy(),
                arguments: value.arguments.map({ $0.copy() }),
                specialization: value.specialization?.copy(),
                type: value.type.copy()
        )

        case let value as Checker.Cast:
            return Checker.Cast(
                callee: value.callee.copy(),
                arguments: value.arguments.map({ $0.copy() }),
                type: value.type.copy(),
                cast: value.cast
        )

        case let value as Checker.Declaration:
            return Checker.Declaration(
                identifier: value.identifier.copy(),
                type: value.type?.copy(),
                value: value.value.copy(),
                isCompileTime: value.isCompileTime,
                entity: value.entity.copy()
        )

        case let value as Checker.FloatLiteral:
            return Checker.FloatLiteral(
                value: value.value,
                type: value.type.copy()
        )

        case let value as Checker.Function:
            return Checker.Function(
                parameters: value.parameters.map({ $0.copy() }),
                returnType: value.returnType.copy(),
                body: value.body.copy(),
                scope: value.scope.copy(),
                isSpecialization: value.isSpecialization,
                type: value.type.copy()
        )

        case let value as Checker.FunctionType:
            return Checker.FunctionType(
                parameters: value.parameters.map({ $0.copy() }),
                returnType: value.returnType.copy(),
                type: value.type.copy()
        )

        case let value as Checker.Identifier:
            return Checker.Identifier(
                name: value.name,
                entity: value.entity.copy()
        )

        case let value as Checker.Infix:
            return Checker.Infix(
                kind: value.kind,
                lhs: value.lhs.copy(),
                rhs: value.rhs.copy(),
                type: value.type.copy(),
                op: value.op,
                lhsCast: value.lhsCast,
                rhsCast: value.rhsCast
        )

        case let value as Checker.IntegerLiteral:
            return Checker.IntegerLiteral(
                value: value.value,
                type: value.type.copy()
        )

        case let value as Checker.Paren:
            return Checker.Paren(
                expr: value.expr.copy(),
                type: value.type.copy()
        )

        case let value as Checker.PointerType:
            return Checker.PointerType(
                pointee: value.pointee.copy(),
                type: value.type.copy()
        )

        case let value as Checker.PolymorphicFunction:
            return Checker.PolymorphicFunction(
                parameters: value.parameters.map({ $0.copy() }),
                returnType: value.returnType.copy(),
                body: value.body.copy(),
                type: value.type.copy(),
                specializations: value.specializations
        )

        case let value as Checker.Prefix:
            return Checker.Prefix(
                kind: value.kind,
                expr: value.expr.copy(),
                type: value.type.copy()
        )

        case let value as Checker.StringLiteral:
            return Checker.StringLiteral(
                value: value.value,
                type: value.type.copy()
        )

        default:
            fatalError()
        }
    }
}

extension AstNode {

    func copy() -> AstNode {
        return AstNode(
            value: value.copy(),
            tokens: tokens
        )
    }
}
extension Entity {

    func copy() -> Entity {
        return Entity(
            ident: ident,
            type: type?.copy(),
            flags: flags,
            value: value
        )
    }
}
extension FunctionSpecialization {

    func copy() -> FunctionSpecialization {
        return FunctionSpecialization(
            specializationIndices: specializationIndices,
            specializedTypes: specializedTypes,
            strippedType: strippedType.copy(),
            fnNode: fnNode.copy(),
            llvm: llvm
        )
    }
}
extension Scope {

    func copy() -> Scope {
        return Scope(
            parent: parent?.copy(),
            members: members
        )
    }
}
extension Type {

    func copy() -> Type {
        return Type(
            entity: entity?.copy(),
            width: width,
            flags: flags,
            value: value
        )
    }
}
