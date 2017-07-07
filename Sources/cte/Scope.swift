
class Scope {

    weak var parent: Scope?

    var file: SourceFile?
    var isFile: Bool {
        return file != nil
    }

    var members: [Entity] = []

    init(parent: Scope? = nil, file: SourceFile? = nil, members: [Entity] = []) {
        self.parent = parent
        self.file = file
        self.members = members
    }

    func lookup(_ name: String) -> Entity? {
        if let found = members.first(where: { $0.name == name }) {
            return found
        }

        return parent?.lookup(name)
    }

    func insert(_ entity: Entity, scopeOwnsEntity: Bool = true) {

        if let existing = members.first(where: { $0.name == entity.name }) {
            reportError("Invalid redeclaration of '\(existing.name)'", at: entity.ident)
            attachNote("Previous declaration here: \(existing.ident.start)")
        }

        if scopeOwnsEntity {
            entity.owningScope = self
        }

        members.append(entity)
    }

    static let global = Scope(members: [BuiltinType.void, .type, .bool, .string, .f32, .f64, .u8, .i64].map({ $0.entity }))
}
