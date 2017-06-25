
import LLVM

struct BuiltinType {

    var entity: Entity
    var type: Type

    init(name: String, width: Int, irType: IRType) {

        entity = Entity.makeBuiltin(name)
        type = Type.makeBuiltin(entity, width: width, irType: irType)

        entity.flags.insert(.type)
        entity.type = Type.makeMetatype(type)

        Scope.global.insert(entity)
    }

    static let void = BuiltinType(name: "void", width: 0, irType: VoidType())
    static let type = BuiltinType(name: "type", width: 64, irType: PointerType.toVoid)
    static let bool = BuiltinType(name: "bool", width: 1, irType: IntType.int1)

    static let string = BuiltinType(name: "string", width: 64, irType: PointerType.toVoid)
    static let f32 = BuiltinType(name: "f32", width: 32, irType: FloatType.double)
    static let f64 = BuiltinType(name: "f64", width: 64, irType: FloatType.double)

    static let u8 = BuiltinType(name: "u8", width: 8, irType: IntType.int8)
    static let i64 = BuiltinType(name: "i64", width: 64, irType: IntType.int64)
}

extension Entity {

    static let void = BuiltinType.void.entity
    static let type = BuiltinType.type.entity
    static let bool = BuiltinType.bool.entity
    static let string = BuiltinType.string.entity
    static let f32 = BuiltinType.f32.entity
    static let f64 = BuiltinType.f64.entity
    static let u8 = BuiltinType.u8.entity
    static let i64 = BuiltinType.i64.entity

    static let anonymous = Entity.makeBuiltin("_")
}

extension Type {
    static let void = BuiltinType.void.type

    static let type = BuiltinType.type.type
    static let bool = BuiltinType.bool.type
    static let string = BuiltinType.string.type
    static let f32 = BuiltinType.f32.type
    static let f64 = BuiltinType.f64.type
    static let u8 = BuiltinType.u8.type
    static let i64 = BuiltinType.i64.type

    static let invalid = Type.makeBuiltin(Entity.anonymous, width: 0, irType: VoidType())
}
