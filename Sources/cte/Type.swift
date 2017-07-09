
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

        case .integer:
            return entity!.name

        case .floatingPoint:
            return entity!.name

        case .boolean: // TODO(vdka): it would be nice to alias bool to `i1`
            return entity!.name

        case .pointer:
            return "*" + (self.value as! Pointer).pointeeType.description

        case .metatype:
            return "Metatype(" + (self.value as! Metatype).instanceType.description + ")"

        case .file:
            return "<file>"

        case .function:
            // fn ($T: type, a: T, b: T) -> T
            let fn = self.asFunction
            return "fn(" + fn.params.map({ $0.description }).joined(separator: ", ") + ")" + " -> " + fn.returnType.description
        }
    }

    var name: String {
        return description
    }

    var isVoid: Bool {
        return kind == .void
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
    case integer
    case floatingPoint
    case boolean
    case function
    case pointer
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
        var returnType: Type
        var isVariadic: Bool
        var needsSpecialization: Bool
    }

    struct Pointer: TypeValue {
        static let typeKind: TypeKind = .pointer

        let pointeeType: Type
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
        return lhs.entity === rhs.entity
    }
}
