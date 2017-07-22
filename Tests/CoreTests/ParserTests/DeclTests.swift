import XCTest
@testable import Core

class DeclTests: XCTestCase {
    override func setUp() {
        Core.errors.removeAll()
    }

    func testVerboseI64() {
        "a: i64 = 10;".expectFromParser([
            TestAst.makeDecl("a", "i64", 10)
        ])
    }

    func testImplicitI64() {
        "a := 99;".expectFromParser([
            TestAst.makeDecl("a", nil, 99)
        ])
    }
}
