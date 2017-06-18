
class Scope {

    weak var parent: Scope?

    var members: [Entity] = []

    init(parent: Scope? = nil) {
        self.parent = parent
        self.members = []
    }

    func lookup(_ name: String) -> Entity? {
        if let found = members.first(where: { $0.name == name }) {
            return found
        }

        return parent?.lookup(name)
    }

    func insert(_ entity: Entity) {

        if let existing = members.first(where: { $0.name == entity.name }) {
            reportError("Invalid redeclaration of '\(existing.name)'", at: entity.ident.location)
        }

        members.append(entity)
    }

    static let global = Scope()
}
