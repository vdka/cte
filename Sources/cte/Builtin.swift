
func declareBuiltins() {

    Entity.void.flags.insert(.type)
    Entity.bool.flags.insert(.type)
    Entity.type.flags.insert(.type)
    Entity.string.flags.insert(.type)
    Entity.number.flags.insert(.type)

    Entity.void.type = Type.makeMetatype(Type.void)
    Entity.bool.type = Type.makeMetatype(Type.bool)
    Entity.type.type = Type.makeMetatype(Type.type)
    Entity.string.type = Type.makeMetatype(Type.string)
    Entity.number.type = Type.makeMetatype(Type.number)

    Entity.print.type = Type(value: Type.Function, entity: <#T##Entity#>)

    Scope.global.insert(Entity.void)
    Scope.global.insert(Entity.bool)
    Scope.global.insert(Entity.type)
    Scope.global.insert(Entity.string)
    Scope.global.insert(Entity.number)
}

extension Entity {

    static let void = Entity.makeBuiltin("void")
    static let bool = Entity.makeBuiltin("bool")
    static let type = Entity.makeBuiltin("type")
    static let string = Entity.makeBuiltin("string")
    static let number = Entity.makeBuiltin("number")

    static let print = Entity.makeBuiltin("print")

    static let anonymous = Entity.makeBuiltin("_")
}

extension Type {

    static let void = Type.makeBuiltin(Entity.void, width: 0)
    static let bool = Type.makeBuiltin(Entity.bool, width: 1)
    static let type = Type.makeBuiltin(Entity.type, width: 64)
    static let string = Type.makeBuiltin(Entity.string, width: 64)
    static let number = Type.makeBuiltin(Entity.number, width: 64)

    static let invalid = Type.makeBuiltin(Entity.anonymous, width: 0)

}
