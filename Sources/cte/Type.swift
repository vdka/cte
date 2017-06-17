
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
}

protocol TypeValue {
    static var typeKind: TypeKind { get }
}

extension Type {
    struct Function: TypeValue {
        static var typeKind = TypeKind.function

        var paramTypes: [Type]
        var returnType: Type
    }

    struct Builtin: TypeValue {
        static var typeKind = TypeKind.builtin
    }
}

extension Type {

    static func makeBuiltin(_ entity: Entity, width: Int) -> Type {
        let type = Type(value: Builtin(), entity: entity)
        type.width = width
        return type
    }
}

extension Type {

    static func == (lhs: Type, rhs: Type) -> Bool {
        return lhs.entity === rhs.entity
    }
}
