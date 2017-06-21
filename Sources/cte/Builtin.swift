
struct BuiltinType {

    var entity: Entity
    var type: Type

    init(name: String, width: Int) {

        entity = Entity.makeBuiltin(name)
        type = Type.makeBuiltin(entity, width: width)

        entity.flags.insert(.type)
        entity.type = Type.makeMetatype(type)

        Scope.global.insert(entity)
    }

    static let void = BuiltinType(name: "void", width: 0)
    static let type = BuiltinType(name: "type", width: 64)
    static let bool = BuiltinType(name: "bool", width: 1)

    static let string = BuiltinType(name: "string", width: 64)
    static let number = BuiltinType(name: "number", width: 64)

    static let u8 = BuiltinType(name: "u8", width: 8)
}

extension Entity {

    static let void = BuiltinType.void.entity
    static let type = BuiltinType.type.entity
    static let bool = BuiltinType.bool.entity
    static let string = BuiltinType.string.entity
    static let number = BuiltinType.number.entity
    static let u8 = BuiltinType.u8.entity

    static let anonymous = Entity.makeBuiltin("_")
}

extension Type {

    static let void = BuiltinType.void.type
    static let type = BuiltinType.type.type
    static let bool = BuiltinType.bool.type
    static let string = BuiltinType.string.type
    static let number = BuiltinType.number.type

    static let u8 = BuiltinType.u8.type

    static let invalid = Type.makeBuiltin(Entity.anonymous, width: 0)

}
