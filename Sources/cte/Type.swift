
import LLVM

class Type: Equatable, CustomStringConvertible {

    weak var entity: Entity?
    var width: Int?

    var kind: TypeKind {
        return Swift.type(of: value).typeKind
    }
    var value: TypeValue

    init<T: TypeValue>(value: T, entity: Entity? = nil) {
        self.entity = entity
        self.width = nil

        self.value = value

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

    static func == (lhs: Type, rhs: Type) -> Bool {
        return lhs.entity === rhs.entity
    }
}
