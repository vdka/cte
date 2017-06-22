
import LLVM

func declareBuiltins() {

    Entity.void.flags.insert(.type)
    Entity.bool.flags.insert(.type)
    Entity.type.flags.insert(.type)
    Entity.string.flags.insert(.type)
    Entity.f64.flags.insert(.type)

    Entity.void.type = Type.makeMetatype(Type.void)
    Entity.bool.type = Type.makeMetatype(Type.bool)
    Entity.type.type = Type.makeMetatype(Type.type)
    Entity.string.type = Type.makeMetatype(Type.string)
    Entity.f64.type = Type.makeMetatype(Type.f64)

    Scope.global.insert(Entity.void)
    Scope.global.insert(Entity.bool)
    Scope.global.insert(Entity.type)
    Scope.global.insert(Entity.string)
    Scope.global.insert(Entity.f64)
}

extension Entity {

    static let void = Entity.makeBuiltin("void")
    static let bool = Entity.makeBuiltin("bool")
    static let type = Entity.makeBuiltin("type")
    static let string = Entity.makeBuiltin("string")

    static let f32 = Entity.makeBuiltin("f32")
    static let f64 = Entity.makeBuiltin("f64")

    static let u8 = Entity.makeBuiltin("u8")
    static let i64 = Entity.makeBuiltin("i64")
    static let u64 = Entity.makeBuiltin("u64")

    static let anonymous = Entity.makeBuiltin("_")
}

extension Type {

    static let void = Type.makeBuiltin(Entity.void, width: 0, irType: VoidType())
    static let bool = Type.makeBuiltin(Entity.bool, width: 1, irType: IntType.int1)
    static let type = Type.makeBuiltin(Entity.type, width: 64, irType: IntType.int64)
    static let string = Type.makeBuiltin(Entity.string, width: 64, irType: PointerType(pointee: IntType.int8))

    static let f32 = Type.makeBuiltin(Entity.f32, width: 32, irType: FloatType.float)
    static let f64 = Type.makeBuiltin(Entity.f64, width: 64, irType: FloatType.double)

    static let u8 = Type.makeBuiltin(Entity.u8, width: 8, irType: IntType.int8)
    static let i64 = Type.makeBuiltin(Entity.i64, width: 64, irType: IntType.int64)
    static let u64 = Type.makeBuiltin(Entity.u64, width: 64, irType: IntType.int64)


    static let invalid = Type.makeBuiltin(Entity.anonymous, width: 0, irType: VoidType())
}
