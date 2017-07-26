
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

    // NOTE: Used for builtins with generics
    static let T = Entity.makeBuiltin("T")
    static let U = Entity.makeBuiltin("U")
    static let V = Entity.makeBuiltin("V")
}

extension Type {
    static let invalid = Type.makeBuiltin(Entity.anonymous, width: 0, value: Type.Void())
    static let cvargsAny = Type(value: Type.CVargsAny())

    static let typeInfo = Type.makeStruct(named: "TypeInfo", [
        ("kind", Type.u8), // TODO: Make this an enumeration
        ("name", Type.string),
        ("width", Type.i64),
    ])
}

class BuiltinEntity {

    var entity: Entity
    var type: Type
    var gen: (IRBuilder) -> IRValue

    init(entity: Entity, type: Type, gen: @escaping (IRBuilder) -> IRValue) {
        self.entity = entity
        self.type = type
        self.gen = {
            if let value = entity.value {
                return value
            }
            entity.value = gen($0)
            return entity.value!
        }
    }

    init(name: String, type: Type, gen: @escaping (IRBuilder) -> IRValue) {
        let token = Token(kind: .ident, value: name, location: .unknown)
        let entity = Entity(ident: token, type: type, flags: .none)
        self.entity = entity
        self.type = type
        self.gen = {
            if let value = entity.value {
                return value
            }
            entity.value = gen($0)
            return entity.value!
        }
    }

    static let trué = BuiltinEntity(name: "true", type: Type.bool, gen: { $0.addGlobal("true", initializer: true.asLLVM()) })
    static let falsé = BuiltinEntity(name: "false", type: Type.bool, gen: { $0.addGlobal("false", initializer: false.asLLVM()) })
}

let polymorphicT = Type.makePolymorphicMetatype(Entity.T)
let polymorphicU = Type.makePolymorphicMetatype(Entity.U)
let polymorphicV = Type.makePolymorphicMetatype(Entity.V)

class BuiltinFunction {

    typealias Generate = (BuiltinFunction, [AstNode], inout IRGenerator) -> IRValue

    var entity: Entity
    var type: Type
    var generate: Generate
    var irValue: IRValue?

    var onCallCheck: ((inout Checker, AstNode) -> Type)?

    init(entity: Entity, generate: @escaping Generate, onCallCheck: ((inout Checker, AstNode) -> Type)?) {
        self.entity = entity
        self.type = entity.type!
        self.generate = generate
        self.onCallCheck = onCallCheck
    }

    /// - Note: OutTypes must be metatypes and will be made instance instanceTypes
    static func make(_ name: String, in inTypes: [Type], out outTypes: [Type], isVariadic: Bool = false, gen: @escaping Generate, onCallCheck: ((inout Checker, AstNode) -> Type)? = nil) -> BuiltinFunction {
        let type = Type.fn(in: inTypes, out: outTypes.map({ $0.asMetatype.instanceType }), isVariadic: isVariadic)

        let token = Token(kind: .ident, value: name, location: .unknown)
        let entity = Entity(ident: token, type: type, flags: .none)

        let fn = BuiltinFunction(entity: entity, generate: gen, onCallCheck: onCallCheck)

        return fn
    }

    static let typeinfo = BuiltinFunction.make("typeinfo", in: [Type.type], out: [Type.typeInfo], gen: typeinfoGen, onCallCheck: { checker, node in
        let call = node.asCall
        assert(call.arguments.count == 1)

        var argType = checker.checkExpr(node: call.arguments[0])

        argType = checker.lowerFromMetatype(argType, atNode: call.arguments[0])

        return Type.makeTuple([Type.typeInfo.asMetatype.instanceType])
    })

    static let bitcast = BuiltinFunction.make("bitcast", in: [polymorphicT.asMetatype.instanceType, Type.type], out: [polymorphicT], gen: bitcastGen, onCallCheck: { checker, node in
        let call = node.asCall
        assert(call.arguments.count == 2)

        let argType = checker.checkExpr(node: call.arguments[0])
        var targetType = checker.checkExpr(node: call.arguments[1])
        targetType = checker.lowerFromMetatype(targetType, atNode: call.arguments[1])

        if argType.width != targetType.width {
            checker.reportError("Bitcast can only be used on types with the same width", at: node)
        }

        return Type.makeTuple([targetType])
    })
}

var typeInfoValues: [Type: IRValue] = [:]
func typeinfoGen(builtinFunction: BuiltinFunction, parameters: [AstNode], generator: inout IRGenerator) -> IRValue {
    
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

func bitcastGen(builtinFunction: BuiltinFunction, parameters: [AstNode], generator: inout IRGenerator) -> IRValue {
    assert(parameters.count == 2)

    let input = generator.emitExpr(node: parameters[0], returnAddress: true)
    var outputType = canonicalize(parameters[1].exprType.asMetatype.instanceType)
    outputType = PointerType(pointee: outputType)
    let pointer = builder.buildBitCast(input, type: outputType)
    return builder.buildLoad(pointer)
}

func lookupBuiltinFunction(_ callee: AstNode) -> BuiltinFunction? {
    return builtinFunctions.first(where: { $0.entity.name == callee.asIdentifier.name })
}
