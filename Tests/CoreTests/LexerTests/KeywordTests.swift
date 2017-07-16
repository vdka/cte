import XCTest
@testable import Core

class KeywordTests: XCTestCase {
    func testIdentifier() {
        "anIdentifier".expectFromLexer(.ident)
    }
}
