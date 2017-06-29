
import LLVM

class Entity: CustomStringConvertible {

    var ident: Token
    var type: Type?
    var flags: Flag = .none

    var value: IRValue?

    var name: String {
        guard case .ident(let ident) = ident.kind else {
            fatalError()
        }
        return ident
    }

    init(ident: Token, type: Type? = nil) {
        guard case .ident = ident.kind else {
            fatalError()
        }
        self.ident = ident
        self.type = type
    }

    init(ident: Token, type: Type?, flags: Flag, value: IRValue?) {
        self.ident = ident
        self.type = type
        self.flags = flags
        self.value = value
    }

    struct Flag: OptionSet {
        let rawValue: UInt8
        static let none = Flag(rawValue: 0b0000_0000)
        static let used = Flag(rawValue: 0b0000_0001)
        static let ct   = Flag(rawValue: 0b0000_0010)
        static let type = Flag(rawValue: 0b1000_0000)
    }

    var description: String {
        return name
    }
}

extension Entity {

    static func makeBuiltin(_ name: String, type: Type? = nil) -> Entity {
        let tok = Token(kind: .ident(name), location: .unknown)
        let entity = Entity(ident: tok)
        entity.type = type
        entity.flags.insert(.ct)
        return entity
    }
}

