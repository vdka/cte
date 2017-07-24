import XCTest
@testable import Core

class DeclTests: XCTestCase {
    override func setUp() {
        Core.errors.removeAll()
    }

    func testVerboseI64() {
        "a: i64 = 10".expectFromParser([
            TestAst.makeDecl("a", "i64", val: 10 as UInt64)
        ])
    }

    func testImplicitI64() {
        "a := 99".expectFromParser([
            TestAst.makeDecl("a", val: 99 as UInt64)
        ])
    }

    func testVerboseF64() {
        "a: f64 = 1.0".expectFromParser([
            TestAst.makeDecl("a", "f64", val: 1.0)
        ])
    }

    func testImplicitF64() {
        "a := 1.0".expectFromParser([
            TestAst.makeDecl("a", val: 1.0)
        ])
    }

    func testVerboseString() {
        "a: string = \"Hello, world!\"".expectFromParser([
            TestAst.makeDecl("a", "string", val: "Hello, world!")
        ])
    }

    func testImplicitString() {
        "a := \"Hello, world!\"".expectFromParser([
            TestAst.makeDecl("a", val: "Hello, world!")
        ])
    }

    func testVerboseIdentifier() {
        "b: string = a".expectFromParser([
            TestAst.makeDecl("b", "string", val: TestAst.ident("a"))
        ])
    }

    func testImplicitIdentifier() {
        "b := a".expectFromParser([
            TestAst.makeDecl("b", val: TestAst.ident("a"))
        ])
    }

    func testImplicitMultiDeclaration() {
        "a, b := 10, 11".expectFromParser([
            TestAst.makeDecl(["a", "b"], values: [10 as UInt64, 11 as UInt64])
        ])
    }
}
