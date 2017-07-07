
import Foundation.NSFileManager
import func Darwin.C.exit
import func Darwin.C.fflush
import LLVM
import cllvm

var targetMachine: TargetMachine!

var currentDirectory = FileManager.default.currentDirectoryPath

var buildDirectory = currentDirectory + "/" + fileExtension + "/"

let fileExtension = ".cte"

/// Ensures everything is preparred for compilation
func performCompilationPreflightChecks(with options: Options) {
    do {
        targetMachine = try TargetMachine()
        try ensureBuildDirectoryExists()
    } catch {
        print("ERROR: \(error)")
        print("  While performing preflight checks")
        exit(1)
    }
}

func ensureBuildDirectoryExists() throws {
    let fm = FileManager.default

    var isDir: ObjCBool = false
    if fm.fileExists(atPath: buildDirectory, isDirectory: &isDir) {
        if !isDir.boolValue {
            throw "cannot write to output directory \(buildDirectory)"
        }
    } else {
        try fm.createDirectory(atPath: buildDirectory, withIntermediateDirectories: false, attributes: nil)
    }
}

func pathToEntityName(_ path: String) -> String? {
    assert(!path.isEmpty)

    func isValidIdentifier(_ str: String) -> Bool {

        if !identChars.contains(str.unicodeScalars.first!) {
            return false
        }

        return str.unicodeScalars.dropFirst()
            .contains(where: { identChars.contains($0) || digits.contains($0) })
    }

    let filename = String(path
        .split(separator: "/").last!
        .split(separator: ".").first!)

    guard isValidIdentifier(filename) else {
        return nil
    }

    return filename
}

func resolveLibraryPath(_ name: String, for currentFilePath: String) -> String? {
    
    if name.hasSuffix(".framework") {
        // FIXME(vdka): We need to support non system frameworks
        return name
    }

    if let fullpath = absolutePath(for: name) {
        return fullpath
    }

    if let fullpath = absolutePath(for: name, relativeTo: currentFilePath) {
        return fullpath
    }

    // If the library does not exist at a relative path, check system library locations
    if let fullpath = absolutePath(for: name, relativeTo: "/usr/local/lib") {
        return fullpath
    }

    return nil
}

func absolutePath(for filePath: String) -> String? {

    let url = URL(fileURLWithPath: filePath)
    do {
        guard try url.checkResourceIsReachable() else { return nil }
    } catch { return nil }

    let absoluteURL = url.absoluteString

    return absoluteURL.components(separatedBy: "file://").last
}

func absolutePath(for filepath: String, relativeTo file: String) -> String? {

    let fileUrl = URL(fileURLWithPath: file)
        .deletingLastPathComponent()
        .appendingPathComponent(filepath)

    do {
        guard try fileUrl.checkResourceIsReachable() else {
            return nil
        }
    } catch {
        return nil
    }

    let absoluteURL = fileUrl.absoluteString
    return absoluteURL.components(separatedBy: "file://").last
}

func removeFile(at path: String) throws {

    let fm = FileManager.default

    try fm.removeItem(atPath: path)
}

extension String {

    enum Color: String {
        case black    = "\u{001B}[30m"
        case red      = "\u{001B}[31m"
        case green    = "\u{001B}[32m"
        case yellow   = "\u{001B}[33m"
        case blue     = "\u{001B}[34m"
        case magenta  = "\u{001B}[35m"
        case cyan     = "\u{001B}[36m"
        case white    = "\u{001B}[37m"
        case reset    = "\u{001B}[0m"
    }

    func colored(_ c: Color) -> String {

        #if Xcode || NO_COLOR
            return self
        #else
            let reset = Color.reset.rawValue
            let code = c.rawValue
            return reset + code + self + reset
        #endif
    }
}

extension String {

    var dirname: String {
        if !self.contains("/") {
            return "."
        }
        return String(self.reversed().drop(while: { $0 != "/" }).reversed())
    }

    var basename: String {
        return String(self.split(separator: "/").last ?? "")
    }
}

/*
    Miscelaneous methods extensions and other tidbits of useful functionality
    that is general enough to not belong in other files.
*/

extension BidirectionalCollection where Index == Int {

    /// The Actual last indexable position of the array
    var lastIndex: Index {
        return endIndex - 1
    }
}

extension Set {

    init<S: Sequence>(_ sequences: S...)
        where S.Iterator.Element: Hashable, S.Iterator.Element == Element
    {

        self.init()

        for element in sequences.joined() {
            insert(element)
        }
    }
}

extension String {

    init(_ unicodeScalars: [UnicodeScalar]) {
        self.init(unicodeScalars.map(Character.init))
    }

    /// This was removed from the stdlib I guess ...
    mutating func append(_ scalar: UnicodeScalar) {
        self.append(Character(scalar))
    }
}

// Combats Boilerplate
extension ExpressibleByStringLiteral where StringLiteralType == StaticString {

    public init(unicodeScalarLiteral value: StaticString) {
        self.init(stringLiteral: value)
    }

    public init(extendedGraphemeClusterLiteral value: StaticString) {
        self.init(stringLiteral: value)
    }
}

// NOTE(vdka): This should only be used in development, there are better ways to do things.
func isMemoryEquivalent<A, B>(_ lhs: A, _ rhs: B) -> Bool {
    var (lhs, rhs) = (lhs, rhs)

    guard MemoryLayout<A>.size == MemoryLayout<B>.size else { return false }

    let lhsPointer = withUnsafePointer(to: &lhs) { $0 }
    let rhsPointer = withUnsafePointer(to: &rhs) { $0 }

    let lhsFirstByte = lhsPointer.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<A>.size) { $0 }
    let rhsFirstByte = rhsPointer.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<B>.size) { $0 }

    let lhsBytes = UnsafeBufferPointer(start: lhsFirstByte, count: MemoryLayout<A>.size)
    let rhsBytes = UnsafeBufferPointer(start: rhsFirstByte, count: MemoryLayout<B>.size)

    for (leftByte, rightByte) in zip(lhsBytes, rhsBytes) {
        guard leftByte == rightByte else { return false }
    }

    return true
}

extension Collection {
    subscript (safe index: Index) -> Iterator.Element? {
        guard startIndex <= index && index < endIndex else {
            return nil
        }
        return self[index]
    }
}

extension Sequence {

    func count(where predicate: @escaping (Iterator.Element) -> Bool) -> Int {
        return reduce(0) { total, el in
            return total + (predicate(el) ? 1 : 0)
        }
    }
}

extension String: Swift.Error {}

func unimplemented(_ featureName: String, file: StaticString = #file, line: UInt = #line) -> Never {
    print("\(file):\(line): Unimplemented feature \(featureName).")
    exit(1)
}

func unimplemented(_ featureName: String, if predicate: Bool, file: StaticString = #file, line: UInt = #line) {
    if predicate {
        unimplemented(featureName, file: file, line: line)
    }
}

func debug<T>(_ value: T, file: StaticString = #file, line: UInt = #line) {
    print("\(line): \(value)")
    fflush(stdout)
}

func debug(file: StaticString = #file, line: UInt = #line) {
    print("\(line): HERE")
    fflush(stdout)
}

func unimplemented(file: StaticString = #file, line: UInt = #line) -> Never {
    print("\(file):\(line): Unimplemented feature.")
    exit(1)
}
