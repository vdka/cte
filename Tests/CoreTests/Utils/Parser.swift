import XCTest
@testable import Core

extension SourceFile {
    convenience init(data: String, absolutePath: String = "/test/file.cte", pathImportedAs: String = "file.cte", importedFrom: SourceFile? = nil) {
        let lexer = Lexer(data: data, absolutePath: absolutePath)

        self.init(
            lexer: lexer,
            fullpath: absolutePath,
            pathImportedAs: pathImportedAs,
            importedFrom: importedFrom
        )
    }
}

extension String {
    func expectFromParser(_ expectedNodes: [TestAst], file: StaticString = #file, line: UInt = #line) {
        let expectedNodes = expectedNodes.expanded

        let sFile = SourceFile(data: self)
        sFile.parseEmittingErrors()
        XCTAssert(sFile.hasBeenParsed, "File was not parsed", file: file, line: line)
        XCTAssertEqual(errors.count, 0, "Parser had \(errors.count) errors", file: file, line: line)
        let nodes = sFile.nodes
        XCTAssertEqual(nodes.count, expectedNodes.count, "The amount of nodes doesn't match expected nodes count", file: file, line: line)

        for (a, b) in zip(nodes, expectedNodes) {
            // This will need to be improved, but making AstValue `Equatable` is a total nightmare
            XCTAssertEqual(a.kind, b.kind, file: file, line: line)
            XCTAssert(Swift.type(of: a.value) == Swift.type(of: b.value), file: file, line: line)
        }
    }
}
