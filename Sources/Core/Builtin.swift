
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

    static let typeInfo = Type.makeStruct([
        ("kind", Type.u8), // TODO: Make this an enumeration
        ("name", Type.string),
        ("width", Type.i64),
    ])
}

class BuiltinFunction {

    typealias Generate = (BuiltinFunction, [AstNode], Module, IRBuilder) -> IRValue

    var entity: Entity
    var type: Type
    var generate: Generate
    var irValue: IRValue?

    init(entity: Entity, generate: @escaping Generate) {
        self.entity = entity
        self.type = entity.type!
        self.generate = generate
    }

    /// - Note: OutTypes must be metatypes and will be made instance instanceTypes
    static func make(_ name: String, in inTypes: [Type], out outTypes: [Type], isVariadic: Bool = false, gen: @escaping Generate) -> BuiltinFunction {
        let type = Type.fn(in: inTypes, out: outTypes.map({ $0.asMetatype.instanceType }), isVariadic: isVariadic)

        let token = Token(kind: .ident, value: name, location: .unknown)
        let entity = Entity(ident: token, type: type, flags: .none)

        let fn = BuiltinFunction(entity: entity, generate: gen)

        return fn
    }

    static let typeof = BuiltinFunction.make("typeof", in: [Type.type], out: [Type.typeInfo], gen: typeofGen)
}

var typeInfoValues: [Type: IRValue] = [:]
func typeofGen(builtinFunction: BuiltinFunction, parameters: [AstNode], module: Module, builder: IRBuilder) -> IRValue {
    
    let typeInfoType = Type.typeInfo.asMetatype.instanceType
    let type = parameters[0].exprType.asMetatype.instanceType

    if let global = typeInfoValues[type] {
        return global
    }

    let aggregateType = (canonicalize(typeInfoType)) as! StructType

    let typeKind = unsafeBitCast(type.kind, to: Int8.self)
    let name = builder.buildGlobalStringPtr(type.description)
    let width = type.width ?? 0

    let values: [IRValue] = [typeKind, name, width]
    assert(values.count == typeInfoType.asStruct.fields.count)

    let global = builder.addGlobal("TI(\(type.description))", initializer: aggregateType.constant(values: values))

    typeInfoValues[type] = global
    return global
}
