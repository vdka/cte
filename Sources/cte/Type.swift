
class Type: CustomStringConvertible {

    var token: Token
    var width: Int?

    init(token: Token) {
        guard case .ident = token.kind else {
            fatalError()
        }
        self.token = token
        self.width = nil
    }

    var description: String {
        guard case .ident(let name) = token.kind else {
            fatalError()
        }
        return name
    }
}

extension Type {

    static func makeBuiltin(_ name: String, width: Int) -> Type {
        let tok = Token(kind: .ident(name), location: .unknown)
        let type = Type(token: tok)
        type.width = width
        return type
    }

    static let invalid = Type.makeBuiltin("<invalid>", width: 0)
}
