// sourcery:inline:LinuxTests
@testable import CoreTests
import XCTest

extension DeclTests {
  static var allTests = [
    ("testVerboseI64", testVerboseI64),
    ("testImplicitI64", testImplicitI64),
    ("testVerboseF64", testVerboseF64),
    ("testImplicitF64", testImplicitF64),
    ("testVerboseString", testVerboseString),
    ("testImplicitString", testImplicitString),
    ("testVerboseIdentifier", testVerboseIdentifier),
    ("testImplicitIdentifier", testImplicitIdentifier),
    ("testImplicitMultiDeclaration", testImplicitMultiDeclaration),
  ]
}

extension KeywordTests {
  static var allTests = [
    ("testIdentifier", testIdentifier),
  ]
}

XCTMain([
  testCase(DeclTests.allTests),
  testCase(KeywordTests.allTests),
])
// sourcery:end
