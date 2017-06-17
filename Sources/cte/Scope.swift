
class Scope {

    weak var parent: Scope?

    var members: [Entity] = []

    init(parent: Scope? = nil) {
        self.parent = parent
        self.members = []
    }

    func lookup(_ name: String) -> Entity? {
        return members.first(where: { $0.name == name })
    }

    func insert(_ entity: Entity) {

        if let existing = lookup(entity.name) {
            reportError("Invalid redeclaration of '\(existing.name)'", at: entity.ident.location)
        }

        members.append(entity)
    }

    static let global = Scope()
}
