// Generated using Sourcery 0.7.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



extension AstNode.Declaration {

    var isCompileTime: Bool {
        return flags.contains(.compileTime) 
    }

    var isForeign: Bool {
        return flags.contains(.foreign) 
    }
}
extension CommonDeclaration {

    var isCompileTime: Bool {
        return flags.contains(.compileTime) 
    }

    var isForeign: Bool {
        return flags.contains(.foreign) 
    }
}

extension AstNode.Function {

    var isVariadic: Bool {
        return flags.contains(.variadic) 
    }

    var isDiscardableResult: Bool {
        return flags.contains(.discardableResult) 
    }

    var isSpecialization: Bool {
        return flags.contains(.specialization) 
    }

    var isCVariadic: Bool {
        return flags.contains(.cVariadic) 
    }
}
extension CommonFunction {

    var isVariadic: Bool {
        return flags.contains(.variadic) 
    }

    var isDiscardableResult: Bool {
        return flags.contains(.discardableResult) 
    }

    var isSpecialization: Bool {
        return flags.contains(.specialization) 
    }

    var isCVariadic: Bool {
        return flags.contains(.cVariadic) 
    }
}

extension AstNode.FunctionType {

    var isVariadic: Bool {
        return flags.contains(.variadic) 
    }

    var isDiscardableResult: Bool {
        return flags.contains(.discardableResult) 
    }

    var isSpecialization: Bool {
        return flags.contains(.specialization) 
    }

    var isCVariadic: Bool {
        return flags.contains(.cVariadic) 
    }
}
extension CommonFunctionType {

    var isVariadic: Bool {
        return flags.contains(.variadic) 
    }

    var isDiscardableResult: Bool {
        return flags.contains(.discardableResult) 
    }

    var isSpecialization: Bool {
        return flags.contains(.specialization) 
    }

    var isCVariadic: Bool {
        return flags.contains(.cVariadic) 
    }
}

extension Checker.Declaration {

    var isCompileTime: Bool {
        return flags.contains(.compileTime) 
    }

    var isForeign: Bool {
        return flags.contains(.foreign) 
    }
}

extension Checker.Function {

    var isVariadic: Bool {
        return flags.contains(.variadic) 
    }

    var isDiscardableResult: Bool {
        return flags.contains(.discardableResult) 
    }

    var isSpecialization: Bool {
        return flags.contains(.specialization) 
    }

    var isCVariadic: Bool {
        return flags.contains(.cVariadic) 
    }
}

extension Checker.FunctionType {

    var isVariadic: Bool {
        return flags.contains(.variadic) 
    }

    var isDiscardableResult: Bool {
        return flags.contains(.discardableResult) 
    }

    var isSpecialization: Bool {
        return flags.contains(.specialization) 
    }

    var isCVariadic: Bool {
        return flags.contains(.cVariadic) 
    }
}

extension Checker.PolymorphicFunction {

    var isVariadic: Bool {
        return flags.contains(.variadic) 
    }

    var isDiscardableResult: Bool {
        return flags.contains(.discardableResult) 
    }

    var isSpecialization: Bool {
        return flags.contains(.specialization) 
    }

    var isCVariadic: Bool {
        return flags.contains(.cVariadic) 
    }
}

