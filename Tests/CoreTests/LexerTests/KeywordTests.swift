import XCTest
@testable import Core

class KeywordTests: XCTestCase {
    func testIdentifier() {
        expectTokenFromLexer("anIdentifier", .ident)
    }
}
