
class Entity {

    var ident: Token
    var type: Type?
    var flags: Flag = .none

    var name: String {
        guard case .ident(let ident) = ident.kind else {
            fatalError()
        }
        return ident
    }

    init(ident: Token) {
        guard case .ident = ident.kind else {
            fatalError()
        }
        self.ident = ident
        self.type = nil
    }

    struct Flag: OptionSet {
        let rawValue: UInt8
        static let none = Flag(rawValue: 0b0000_0000)
        static let used = Flag(rawValue: 0b0000_0001)
        static let core = Flag(rawValue: 0b1000_0000)
    }
}

extension Entity {

    static func makeBuiltin(_ name: String, type: Type? = nil) -> Entity {
        let tok = Token(kind: .ident(name), location: .unknown)
        let entity = Entity(ident: tok)
        entity.type = type
        return entity
    }
}

