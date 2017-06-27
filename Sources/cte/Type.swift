
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
        static let number  = Flag(rawValue: 0b1000_0000)
        static let integer = Flag(rawValue: 0b1100_0000)
        static let signed  = Flag(rawValue: 0b1110_0000)
        static let float   = Flag(rawValue: 0b1001_0000)
    }

    var description: String {
        if self === Type.invalid {
            return "<invalid>"
        }

        switch kind {
        case .builtin:
            return entity!.name

        case .pointer:
            return "*" + (self.value as! Pointer).pointeeType.description

        case .metatype:
            return "Metatype(" + (self.value as! Metatype).instanceType.description + ")"

        case .function:
            fatalError()
        }
    }

    var name: String {
        return description
    }

    var isNumber: Bool {
        return flags.contains(.number)
    }

    var isInteger: Bool {
        return flags.contains(.integer)
    }

    var isSignedInteger: Bool {
        return flags.contains(.signed)
    }

    var isUnsignedInteger: Bool {
        return flags.contains(.integer) && !flags.contains(.signed)
    }

    var isFloatingPoint: Bool {
        return flags.contains(.float)
    }

    func compatibleWithoutExtOrTrunc(_ type: Type) -> Bool {
        return type == self
    }

    func compatibleWithExtOrTrunc(_ type: Type) -> Bool {
        if type.flags.contains(.integer) && self.flags.contains(.integer) {
            return true
        }

        if type.flags.contains(.float) && self.flags.contains(.float) {
            return true
        }

        return false
    }
}

enum TypeKind {
    case function
    case pointer
    case builtin
    case metatype
}

protocol TypeValue {
    static var typeKind: TypeKind { get }
}

extension Type {
    struct Function: TypeValue {
        static let typeKind = TypeKind.function

        var node: AstNode
        var params: [Entity]
        var returnType: Type
        var needsSpecialization: Bool
    }

    struct Pointer: TypeValue {
        static let typeKind = TypeKind.pointer

        let pointeeType: Type
    }

    struct Builtin: TypeValue {
        static let typeKind = TypeKind.builtin

        let canonicalRepresentation: IRType
    }

    struct Metatype: TypeValue {
        static let typeKind = TypeKind.metatype

        let instanceType: Type
    }
}

extension Type {

    static func makePointer(to pointeeType: Type) -> Type {
        let pointer = Pointer(pointeeType: pointeeType)
        return Type(value: pointer)
    }

    static func makeBuiltin(_ entity: Entity, width: Int, irType: IRType) -> Type {
        let type = Type(value: Builtin(canonicalRepresentation: irType), entity: entity)
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
        return lhs.entity === rhs.entity
    }
}
