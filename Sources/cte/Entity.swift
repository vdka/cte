
import LLVM

class Entity: CustomStringConvertible {

    var ident: Token
    var type: Type?
    var flags: Flag = .none

    var memberScope: Scope?

    /// The scope that 'owns' this Entity
    var owningScope: Scope!

    var value: IRValue?

    var name: String {
        assert(ident.kind == .ident)
        return ident.value as! String
    }

    init(ident: Token, type: Type? = nil, flags: Flag = .none) {
        guard case .ident = ident.kind else {
            fatalError()
        }
        self.ident = ident
        self.type = type
        self.flags = flags
    }

    init(ident: Token, type: Type?, flags: Flag, memberScope: Scope?, owningScope: Scope?, value: IRValue?) {
        self.ident = ident
        self.type = type
        self.flags = flags
        self.memberScope = memberScope
        self.owningScope = owningScope
        self.value = value
    }

    struct Flag: OptionSet {
        let rawValue: UInt8
        static let none         = Flag(rawValue: 0b0000_0000)
        static let used         = Flag(rawValue: 0b0000_0001)
        static let file         = Flag(rawValue: 0b0000_0010)
        static let library      = Flag(rawValue: 0b0000_0100)
        static let type         = Flag(rawValue: 0b0001_0000)
        static let compileTime  = Flag(rawValue: 0b0010_0000)
        static let implicitType = Flag(rawValue: 0b0111_0000)
        static let foreign      = Flag(rawValue: 0b1000_0000)
    }

    var description: String {
        return name
    }
}

extension Entity {

    static func makeBuiltin(_ name: String, type: Type? = nil) -> Entity {
        let tok = Token(kind: .ident, value: name, location: .unknown)
        let entity = Entity(ident: tok)
        entity.type = type
        entity.flags.insert(.compileTime)
        return entity
    }
}
