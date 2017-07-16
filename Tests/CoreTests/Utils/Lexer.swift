import XCTest
@testable import Core

extension Lexer {
    /// A convenient way to create a lexer without a `real` file
    init(data: String, absolutePath: String = "/test/file.cte") {
        let file = File(data: data, absolutePath: absolutePath)
        scanner = FileScanner(file: file)
        lastLocation = .unknown
        buffer = []
    }
}

extension String {
    func expectFromLexer(_ expectedToken: Token.Kind, file: StaticString = #file, line: UInt = #line) {
        var lexer = Lexer(data: self)
        let token = lexer.next()
        XCTAssertNotNil(token, file: file, line: line)
        XCTAssertEqual(token?.kind, expectedToken, file: file, line: line)
    }
}
