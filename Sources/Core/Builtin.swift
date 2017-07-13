
import LLVM

struct BuiltinType {

    var entity: Entity
    var type: Type

    init(name: String, width: Int, flags: Type.Flag, type: TypeValue) {

        entity = Entity.makeBuiltin(name)
        self.type = Type.makeBuiltin(entity, width: width, value: type)
        self.type.flags = flags

        entity.flags.insert(.type)
        entity.type = Type.makeMetatype(self.type)
    }

    static let void = BuiltinType(name: "void", width: 0,  flags: .none, type: Type.Void())
    static let type = BuiltinType(name: "type", width: 64, flags: .none, type: Type.Void())
    static let any  = BuiltinType(name: "any", width: 128, flags: .none, type: Type.Any())

    static let bool = BuiltinType(name: "bool", width: 1,  flags: .none, type: Type.Boolean())
    static let rawptr = BuiltinType(name: "rawptr", width: 64, flags: .none, type: Type.makePointer(to: Type.u8).asPointer)
    static let string = BuiltinType(name: "string", width: 64, flags: .none, type: Type.rawptr.asPointer)

    static let f32 = BuiltinType(name: "f32", width: 32, flags: .none, type: Type.FloatingPoint())
    static let f64 = BuiltinType(name: "f64", width: 64, flags: .none, type: Type.FloatingPoint())
    static let u8  = BuiltinType(name: "u8",  width: 8,  flags: .none, type: Type.Integer(isSigned: false))
    static let i32 = BuiltinType(name: "i32", width: 32, flags: .none, type: Type.Integer(isSigned: true))
    static let i64 = BuiltinType(name: "i64", width: 64, flags: .none, type: Type.Integer(isSigned: true))

}

extension Entity {
    static let anonymous = Entity.makeBuiltin("_")
}

extension Type {
    static let invalid = Type.makeBuiltin(Entity.anonymous, width: 0, value: Type.Void())
    static let cvargsAny = Type(value: Type.CVargsAny())
}
