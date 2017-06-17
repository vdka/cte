
func declareBuiltins() {

    let string = Entity.makeBuiltin("string", type: Type.string)
    let number = Entity.makeBuiltin("number", type: Type.number)

    Scope.global.insert(string)
    Scope.global.insert(number)
}

extension Type {

    static let string = Type.makeBuiltin("string", width: 64)
    static let number = Type.makeBuiltin("number", width: 64)
}
