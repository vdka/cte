// Generated using Sourcery 0.7.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


extension AstValue {

    func copy() -> AstValue {
        switch self {

        case let value as AstNode.Assign:
            return AstNode.Assign(
                lvalues: value.lvalues.map({ $0.copy() }),
                rvalues: value.rvalues.map({ $0.copy() })
        )

        case let value as AstNode.Block:
            return AstNode.Block(
                stmts: value.stmts.map({ $0.copy() }),
                isForeign: value.isForeign,
                isFunction: value.isFunction
        )

        case let value as AstNode.Break:
            return AstNode.Break(
                label: value.label?.copy()
        )

        case let value as AstNode.Call:
            return AstNode.Call(
                callee: value.callee.copy(),
                arguments: value.arguments.map({ $0.copy() })
        )

        case let value as AstNode.Case:
            return AstNode.Case(
                condition: value.condition?.copy(),
                block: value.block.copy()
        )

        case let value as AstNode.Comment:
            return AstNode.Comment(
                comment: value.comment
        )

        case let value as AstNode.CompileTime:
            return AstNode.CompileTime(
                stmt: value.stmt.copy()
        )

        case let value as AstNode.Continue:
            return AstNode.Continue(
                label: value.label?.copy()
        )

        case let value as AstNode.Declaration:
            return AstNode.Declaration(
                names: value.names.map({ $0.copy() }),
                type: value.type?.copy(),
                values: value.values.map({ $0.copy() }),
                linkName: value.linkName,
                flags: value.flags
        )

        case is AstNode.Empty:
            return AstNode.Empty()

        case is AstNode.Fallthrough:
            return AstNode.Fallthrough()

        case let value as AstNode.FloatLiteral:
            return AstNode.FloatLiteral(
                value: value.value
        )

        case let value as AstNode.For:
            return AstNode.For(
                label: value.label?.copy(),
                initializer: value.initializer?.copy(),
                condition: value.condition?.copy(),
                step: value.step?.copy(),
                body: value.body.copy()
        )

        case let value as AstNode.Foreign:
            return AstNode.Foreign(
                library: value.library.copy(),
                stmt: value.stmt.copy()
        )

        case let value as AstNode.Function:
            return AstNode.Function(
                parameters: value.parameters.map({ $0.copy() }),
                returnTypes: value.returnTypes.map({ $0.copy() }),
                body: value.body.copy(),
                flags: value.flags
        )

        case let value as AstNode.FunctionType:
            return AstNode.FunctionType(
                parameters: value.parameters.map({ $0.copy() }),
                returnTypes: value.returnTypes.map({ $0.copy() }),
                flags: value.flags
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

        case let value as AstNode.Import:
            return AstNode.Import(
                path: value.path,
                symbol: value.symbol?.copy(),
                includeSymbolsInParentScope: value.includeSymbolsInParentScope,
                file: value.file.copy()
        )

        case let value as AstNode.Infix:
            return AstNode.Infix(
                token: value.token,
                lhs: value.lhs.copy(),
                rhs: value.rhs.copy()
        )

        case let value as AstNode.IntegerLiteral:
            return AstNode.IntegerLiteral(
                value: value.value
        )

        case is AstNode.Invalid:
            return AstNode.Invalid()

        case let value as AstNode.Library:
            return AstNode.Library(
                path: value.path,
                symbol: value.symbol?.copy()
        )

        case let value as AstNode.List:
            return AstNode.List(
                values: value.values.map({ $0.copy() })
        )

        case let value as AstNode.MemberAccess:
            return AstNode.MemberAccess(
                aggregate: value.aggregate.copy(),
                member: value.member.copy()
        )

        case let value as AstNode.Parameter:
            return AstNode.Parameter(
                name: value.name.copy(),
                type: value.type.copy()
        )

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
                token: value.token,
                expr: value.expr.copy()
        )

        case let value as AstNode.Return:
            return AstNode.Return(
                values: value.values.map({ $0.copy() })
        )

        case let value as AstNode.StringLiteral:
            return AstNode.StringLiteral(
                value: value.value
        )

        case let value as AstNode.Switch:
            return AstNode.Switch(
                label: value.label?.copy(),
                subject: value.subject?.copy(),
                cases: value.cases.map({ $0.copy() })
        )

        case let value as AstNode.Variadic:
            return AstNode.Variadic(
                type: value.type.copy(),
                cCompatible: value.cCompatible
        )

        case let value as Checker.Block:
            return Checker.Block(
                stmts: value.stmts.map({ $0.copy() }),
                isForeign: value.isForeign,
                isFunction: value.isFunction,
                scope: value.scope.copy()
        )

        case let value as Checker.Break:
            return Checker.Break(
                label: value.label?.copy(),
                target: value.target.copy()
        )

        case let value as Checker.Call:
            return Checker.Call(
                callee: value.callee.copy(),
                arguments: value.arguments.map({ $0.copy() }),
                specialization: value.specialization?.copy(),
                type: value.type.copy()
        )

        case let value as Checker.Case:
            return Checker.Case(
                condition: value.condition?.copy(),
                block: value.block.copy(),
                scope: value.scope.copy(),
                fallthroughTarget: value.fallthroughTarget.copy()
        )

        case let value as Checker.Cast:
            return Checker.Cast(
                callee: value.callee.copy(),
                arguments: value.arguments.map({ $0.copy() }),
                type: value.type.copy(),
                cast: value.cast
        )

        case let value as Checker.Continue:
            return Checker.Continue(
                label: value.label?.copy(),
                target: value.target.copy()
        )

        case let value as Checker.Declaration:
            return Checker.Declaration(
                names: value.names.map({ $0.copy() }),
                type: value.type?.copy(),
                values: value.values.map({ $0.copy() }),
                linkName: value.linkName,
                flags: value.flags,
                entities: value.entities.map({ $0.copy() })
        )

        case let value as Checker.Fallthrough:
            return Checker.Fallthrough(
                target: value.target.copy()
        )

        case let value as Checker.FloatLiteral:
            return Checker.FloatLiteral(
                value: value.value,
                type: value.type.copy()
        )

        case let value as Checker.For:
            return Checker.For(
                label: value.label?.copy(),
                initializer: value.initializer?.copy(),
                condition: value.condition?.copy(),
                step: value.step?.copy(),
                body: value.body.copy(),
                continueTarget: value.continueTarget.copy(),
                breakTarget: value.breakTarget.copy()
        )

        case let value as Checker.Function:
            return Checker.Function(
                parameters: value.parameters.map({ $0.copy() }),
                returnTypes: value.returnTypes.map({ $0.copy() }),
                body: value.body.copy(),
                flags: value.flags,
                scope: value.scope.copy(),
                type: value.type.copy()
        )

        case let value as Checker.FunctionType:
            return Checker.FunctionType(
                parameters: value.parameters.map({ $0.copy() }),
                returnTypes: value.returnTypes.map({ $0.copy() }),
                flags: value.flags,
                type: value.type.copy()
        )

        case let value as Checker.Identifier:
            return Checker.Identifier(
                name: value.name,
                entity: value.entity.copy()
        )

        case let value as Checker.Infix:
            return Checker.Infix(
                token: value.token,
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

        case let value as Checker.MemberAccess:
            return Checker.MemberAccess(
                aggregate: value.aggregate.copy(),
                member: value.member.copy(),
                entity: value.entity.copy()
        )

        case let value as Checker.Parameter:
            return Checker.Parameter(
                name: value.name.copy(),
                type: value.type.copy(),
                entity: value.entity.copy(),
                implicitPolymorphicTypeEntity: value.implicitPolymorphicTypeEntity?.copy()
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
                returnTypes: value.returnTypes.map({ $0.copy() }),
                body: value.body.copy(),
                flags: value.flags,
                type: value.type.copy(),
                declaringScope: value.declaringScope.copy(),
                specializations: value.specializations
        )

        case let value as Checker.Prefix:
            return Checker.Prefix(
                token: value.token,
                expr: value.expr.copy(),
                type: value.type.copy()
        )

        case let value as Checker.StringLiteral:
            return Checker.StringLiteral(
                value: value.value,
                type: value.type.copy()
        )

        case let value as Checker.Switch:
            return Checker.Switch(
                label: value.label?.copy(),
                subject: value.subject?.copy(),
                cases: value.cases.map({ $0.copy() }),
                breakTarget: value.breakTarget.copy()
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
extension DeclTests {

    func copy() -> DeclTests {
        return DeclTests(
        )
    }
}
extension Entity {

    func copy() -> Entity {
        return Entity(
            ident: ident,
            type: type?.copy(),
            flags: flags,
            memberScope: memberScope?.copy(),
            owningScope: owningScope?.copy(),
            value: value
        )
    }
}
extension FunctionSpecialization {

    func copy() -> FunctionSpecialization {
        return FunctionSpecialization(
            specializedTypes: specializedTypes,
            strippedType: strippedType.copy(),
            generatedFunctionNode: generatedFunctionNode.copy(),
            llvm: llvm
        )
    }
}
extension JumpTarget {

    func copy() -> JumpTarget {
        return JumpTarget(
            llvm: llvm
        )
    }
}
extension Scope {

    func copy() -> Scope {
        return Scope(
            parent: parent?.copy(),
            owningNode: owningNode?.copy(),
            file: file?.copy(),
            members: members
        )
    }
}

extension Type {

    func copy() -> Type {
        // no need to copy Types
        return self
    }
}

extension SourceFile {

    func copy() -> SourceFile {
        // no need to copy SourceFiles
        return self
    }
}

