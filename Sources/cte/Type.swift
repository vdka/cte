
class Type: Equatable, CustomStringConvertible {

    unowned var entity: Entity
    var kind: TypeKind
    var width: Int?

    var value: UnsafeMutableRawBufferPointer

    init<T: TypeValue>(value: T, entity: Entity) {
        self.kind = T.typeKind
        self.entity = entity
        self.width = nil

        let buffer = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<T>.size)
        buffer.baseAddress!.assumingMemoryBound(to: T.self).initialize(to: value)

        self.value = buffer

    }

    var description: String {

        switch kind {
        case .builtin:
            return name

        case .metatype:
            return "Metatype(" + asMetatype.instanceType.description + ")"

        case .function:
            fatalError()
        }
    }

    var name: String {
        return entity.name
    }
}

enum TypeKind {
    case function
    case builtin
    case metatype
}

protocol TypeValue {
    static var typeKind: TypeKind { get }
}

extension Type {
    struct Function: TypeValue {
        static var typeKind = TypeKind.function

        var node: AstNode
        var params: [Entity]
        var returnType: Type
        var needsSpecialization: Bool
    }

    struct Builtin: TypeValue {
        static var typeKind = TypeKind.builtin
    }

    struct Metatype: TypeValue {
        static var typeKind = TypeKind.metatype

        var instanceType: Type
    }
}

extension Type {

    static func makeBuiltin(_ entity: Entity, width: Int) -> Type {
        let type = Type(value: Builtin(), entity: entity)
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
