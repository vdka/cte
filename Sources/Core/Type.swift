
import LLVM

class Type: Hashable, CustomStringConvertible {

    weak var entity: Entity?
    var width: Int?

    var flags: Flag = .none

    var value: TypeValue
    var kind: TypeKind {
        return Swift.type(of: value).typeKind
    }

    init<T: TypeValue>(value: T, entity: Entity? = nil) {
        self.entity = entity
        self.width = nil

        self.value = value
    }

    init(entity: Entity?, width: Int?, flags: Flag, value: TypeValue) {
        self.entity = entity
        self.width = width
        self.flags = flags
        self.value = value
    }

    struct Flag: OptionSet {
        let rawValue: UInt8
        static let none    = Flag(rawValue: 0b0000_0000)
        static let used    = Flag(rawValue: 0b0000_0001)
    }

    var description: String {
        if self === Type.invalid {
            return "<invalid>"
        }

        switch kind {
        case .void:
            return entity!.name

        case .any:
            return "any"

        case .cvargsAny:
            return "#cvargs ..any"

        case .integer:
            return entity!.name

        case .floatingPoint:
            return entity!.name

        case .boolean: // TODO(vdka): it would be nice to alias bool to `i1`
            return entity!.name

        case .pointer:
            return "*" + (self.value as! Pointer).pointeeType.description

        case .polymorphic:
            return "$" + entity!.name

        case .metatype:
            return "Metatype(" + (self.value as! Metatype).instanceType.description + ")"

        case .file:
            return "<file>"

        case .function:
            // fn ($T: type, a: T, b: T) -> T
            let fn = self.asFunction
            let params = fn.params.map({ $0.description }).joined(separator: ", ")
            let returns = fn.returnType.asTuple.types.map({ $0.description }).joined(separator: ", ")
            return "fn(" + params + ")" + " -> " + returns

        case .struct:
            return "struct { \n" + asStruct.fields.map({ "    " + $0.name + ": " + $0.type.description }).joined(separator: "\n") + "\n}"

        case .union:
            return "union { \n" + asUnion.fields.map({ "    " + $0.name + ": " + $0.type.description }).joined(separator: "\n") + "\n}"

        case .tuple:
            return "(" + asTuple.types.map({ $0.description }).joined(separator: ", ") + ")"
        }
    }

    var name: String {
        return description
    }

    var isVoid: Bool {
        return kind == .void || (kind == .tuple && (asTuple.types.isEmpty || asTuple.types[0].isVoid))
    }

    var isAny: Bool {
        return kind == .any
    }

    var isCVargAny: Bool {
        return kind == .cvargsAny
    }

    var isBoolean: Bool {
        return kind == .boolean
    }

    var isBooleanesque: Bool {
        return isBoolean || isNumber
    }

    var isNumber: Bool {
        return isInteger || isFloatingPoint
    }

    var isInteger: Bool {
        return kind == .integer
    }

    var isSignedInteger: Bool {
        return (value as? Integer)?.isSigned == true
    }

    var isUnsignedInteger: Bool {
        return (value as? Integer)?.isSigned == false
    }

    var isFloatingPoint: Bool {
        return kind == .floatingPoint
    }

    var isFunction: Bool {
        return kind == .function
    }

    var isFunctionPointer: Bool {
        return kind == .pointer && asPointer.pointeeType.isFunction
    }

    var isTuple: Bool {
        return kind == .tuple
    }

    var isPolymorhpic: Bool {
        return kind == .polymorphic
    }

    var isMetatype: Bool {
        return kind == .metatype
    }

    func compatibleWithoutExtOrTrunc(_ type: Type) -> Bool {
        return type == self
    }

    func compatibleWithExtOrTrunc(_ type: Type) -> Bool {
        if type.isInteger && self.isInteger {
            return true
        }

        if type.isFloatingPoint && self.isFloatingPoint {
            return true
        }

        return false
    }

    static func lowerFromMetatype(_ type: Type) -> Type {
        assert(type.kind == .metatype)

        return type.asMetatype.instanceType
    }
}

enum TypeKind {
    case void
    case any
    case cvargsAny
    case integer
    case floatingPoint
    case boolean
    case function
    case `struct`
    case union
    case tuple
    case pointer
    case polymorphic
    case metatype
    case file
}

protocol TypeValue {
    static var typeKind: TypeKind { get }
}

extension Type {

    struct Void: TypeValue {
        static let typeKind: TypeKind = .void
    }

    struct `Any`: TypeValue {
        static let typeKind: TypeKind = .any
    }

    struct CVargsAny: TypeValue {
        static let typeKind: TypeKind = .cvargsAny
    }

    struct Integer: TypeValue {
        static let typeKind: TypeKind = .integer
        var isSigned: Bool
    }

    struct FloatingPoint: TypeValue {
        static let typeKind: TypeKind = .floatingPoint
    }

    struct Boolean: TypeValue {
        static let typeKind: TypeKind = .boolean
    }

    struct Function: TypeValue {
        static let typeKind: TypeKind = .function

        var node: AstNode
        var params: [Type]
        /// - Note: Always a tuple type.
        var returnType: Type
        var flags: Flag

        var isVariadic: Bool { return flags.contains(.variadic) }
        var isCVariadic: Bool { return flags.contains(.cVariadic) }
        var needsSpecialization: Bool { return flags.contains(.polymorphic) }
        var isBuiltin: Bool { return flags.contains(.builtin) }

        struct Flag: OptionSet {
            var rawValue: UInt8

            static let none         = Flag(rawValue: 0b0000)
            static let variadic     = Flag(rawValue: 0b0001)
            static let cVariadic    = Flag(rawValue: 0b0011)
            static let polymorphic  = Flag(rawValue: 0b0100)
            static let builtin      = Flag(rawValue: 0b1000)
        }
    }

    struct Struct: TypeValue {
        static let typeKind: TypeKind = .struct

        var node: AstNode
        var fields: [Field] = []

        struct Field {
            let ident: Token
            let type: Type

            var index: Int
            var offset: Int

            var name: String {
                return ident.stringValue
            }
        }
    }

    struct Union: TypeValue {
        static let typeKind: TypeKind = .union

        var node: AstNode
        var fields: [Field] = []

        struct Field {
            let ident: Token
            let type: Type

            var name: String {
                return ident.stringValue
            }
        }
    }

    struct Tuple: TypeValue {
        static let typeKind: TypeKind = .tuple

        var types: [Type]
    }

    struct Pointer: TypeValue {
        static let typeKind: TypeKind = .pointer

        let pointeeType: Type
    }

    struct Polymorphic: TypeValue {
        static let typeKind: TypeKind = .polymorphic
    }

    struct Metatype: TypeValue {
        static let typeKind: TypeKind = .metatype

        let instanceType: Type
    }

    struct File: TypeValue {
        static let typeKind: TypeKind = .file

        let memberScope: Scope
    }
}

extension Type {

    var memberScope: Scope? {
        switch self.kind {
        case .file:
            return asFile.memberScope

        default:
            return nil
        }
    }
}

extension Type {

    static func makePointer(to pointeeType: Type) -> Type {
        let pointer = Pointer(pointeeType: pointeeType)
        return Type(value: pointer)
    }

    static func makeBuiltin(_ entity: Entity, width: Int, value: TypeValue) -> Type {
        let type = Type(entity: entity, width: width, flags: .none, value: value)
        type.width = width
        return type
    }

    static func fn(in params: [Type], out returns: [Type], isVariadic: Bool = false) -> Type {
        let ret = Type.makeTuple(returns)
        let fn = Type.Function(node: .invalid, params: params, returnType: ret, flags: isVariadic ? [.variadic, .builtin] : .builtin)
        let type = Type(entity: nil, width: nil, flags: .none, value: fn)
        return type
    }

    static func makeStruct(_ members: [(String, Type)]) -> Type {

        var width = 0
        var fields: [Type.Struct.Field] = []
        for (index, (name, type)) in members.enumerated() {

            let token = Token(kind: .ident, value: name, location: .unknown)

            let field = Type.Struct.Field(ident: token, type: type, index: index, offset: width)
            fields.append(field)

            width = (width + (type.width ?? 0)).round(upToNearest: 8)
        }

        let value = Type.Struct(node: .empty, fields: fields)
        let type = Type(entity: nil, width: width, flags: .none, value: value)

        return Type.makeMetatype(type)
    }

    static func makeTuple(_ types: [Type]) -> Type {
        let tuple = Tuple(types: types)
        let type = Type(value: tuple)

        type.width = 0
        for memberType in types {
            guard let typeWidth = memberType.width else {
                type.width = nil
                break
            }

            type.width! += typeWidth
        }
        return type
    }

    static func makePolymorphicMetatype(_ entity: Entity) -> Type {
        let polymorphic = Polymorphic()
        let type = Type(value: polymorphic, entity: entity)
        entity.type = Type.makeMetatype(type)
        return entity.type!
    }

    static func makeMetatype(_ type: Type) -> Type {
        let metatype = Metatype(instanceType: type)
        let type = Type(value: metatype, entity: .anonymous)
        return type
    }
}

extension Type {

    var hashValue: Int {
        return unsafeBitCast(self, to: Int.self) // classes are just pointers after all
    }

    static func == (lhs: Type, rhs: Type) -> Bool {
        if lhs === Type.type {
            return rhs.isMetatype || rhs === Type.type
        }
        if rhs === Type.type {
            return lhs.isMetatype || lhs === Type.type
        }
        if lhs.isMetatype && rhs.isMetatype {
            return lhs.asMetatype.instanceType == rhs.asMetatype.instanceType
        }
        if lhs.isTuple, lhs.asTuple.types.count == 1 {
            return lhs.asTuple.types[0] == rhs
        }
        if rhs.isTuple, rhs.asTuple.types.count == 1 {
            return rhs.asTuple.types[0] == lhs
        }
        return lhs.entity === rhs.entity
    }
}
