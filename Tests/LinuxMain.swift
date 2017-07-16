// sourcery:inline:LinuxTests
@testable import CoreTests
import XCTest

extension DeclTests {
  static var allTests = [
    ("testBasic", testBasic),
  ]
}

XCTMain([
  testCase(DeclTests.allTests),
])
// sourcery:end
