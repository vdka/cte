
let digits        = Array("1234567890".unicodeScalars)
let hexDigits   = digits + Array("abcdefABCDEF".unicodeScalars)
let opChars     = Array("~!%^&+-*/=<>|?".unicodeScalars)
let identChars  = Array("_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".unicodeScalars)
let whitespace  = Array(" \t\n\r".unicodeScalars)

typealias SourceRange = Range<SourceLocation>
struct SourceLocation {

    var line: UInt
    var column: UInt
    let file: String

    static let unknown = SourceLocation(line: 0, column: 0, file: "unknown")
}

extension Range where Bound == SourceLocation {

    static let unknown = SourceLocation.unknown ..< SourceLocation.unknown
}

extension SourceLocation: CustomStringConvertible {

    var description: String {
        let baseName = file.characters.split(separator: "/").map(String.init).last!
        return "\(baseName):\(line):\(column)"
    }
}

extension SourceLocation: Equatable, Comparable {

    static func ==(lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        return lhs.file == rhs.file && lhs.line == rhs.line && lhs.column == rhs.column
    }

    /// - Precondition: both must be in the same file
    static func < (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        if lhs.file != "unknown" && rhs.file != "unknown" {
            precondition(lhs.file == rhs.file)
        }

        return lhs.line < rhs.line
    }
}

struct Lexer {

    var scanner: FileScanner
    var buffer: [Token] = []

    var location: SourceLocation { return scanner.position }
    var lastLocation: SourceRange

    init(_ file: File) {

        self.scanner = FileScanner(file: file)
        self.lastLocation = .unknown
    }

    mutating func next() -> Token? {

        skipWhitespace()

        guard var char = scanner.peek() else { return nil }

        var charactersToPop = 1

        defer {
            scanner.pop(charactersToPop)
        }

        let location = scanner.position
        var kind: Token.Kind
        switch char {
        case "\n": kind = .newline
        case "(": kind = .lparen
        case ")": kind = .rparen
        case "{": kind = .lbrace
        case "}": kind = .rbrace
        case ":": kind = .colon
        case ",": kind = .comma
        case "$": kind = .dollar
        case "+": kind = .plus
        case "*": kind = .asterix
        case "&": kind = .ampersand
        case "=": kind = .equals
        case "<":
            guard !scanner.hasPrefix("<=") else {
                charactersToPop = 2
                kind = .lte
                break
            }
            kind = .lt

        case ">":
            guard !scanner.hasPrefix(">=") else {
                charactersToPop = 2
                kind = .gte
                break
            }
            kind = .gt

        case "-":
            guard !scanner.hasPrefix("->") else {
                charactersToPop = 2
                kind = .returnArrow
                break
            }
            kind = .minus

        case "/":
            let isBlockComment: Bool

            let nextChar = scanner.peek(aheadBy: 1)
            if nextChar == "/" {
                isBlockComment = false
            } else if nextChar == "*" {
                isBlockComment = true
            } else {
                kind = .divide
                break
            }

            charactersToPop = 0

            let comment: String
            if isBlockComment {
                comment = consumeBlockComment()
            } else {
                comment = consumeComment()
            }

            kind = .comment(comment)

        case "\"":
            charactersToPop = 0
            scanner.pop()

            var string = ""
            while let char = scanner.peek(), char != "\"" {
                string.append(char)
                scanner.pop()
            }

            guard scanner.hasPrefix("\"") else { // String is unterminated.
                kind = .invalid("\"" + string)
                break
            }

            scanner.pop()

            kind = .string(string)

        default:
            charactersToPop = 0
            if identChars.contains(char) {

                var string = ""
                while let char = scanner.peek(), (identChars + digits).contains(char) {
                    string.append(char)
                    scanner.pop()
                }

                switch string {
                case "fn": kind = .keywordFn
                case "if": kind = .keywordIf
                case "else": kind = .keywordElse
                case "return": kind = .keywordReturn
                case "struct": kind = .keywordStruct
                default: kind = .ident(string)
                }
            } else if digits.contains(char) {

                var isFloat = false
                var string = ""
                while let char = scanner.peek(), (identChars + digits + [".", "-"]).contains(char) {
                    if [".", "e", "E"].contains(char) {
                        isFloat = true
                    }
                    string.append(char)
                    scanner.pop()
                }

                if !isFloat, let val = UInt64(string) {
                    kind = .integer(val)
                } else if let val = Double(string) {
                    kind = .float(val)
                } else {
                    kind = .invalid(string)
                }
            } else {

                var string = ""
                while let char = scanner.peek(), !whitespace.contains(char) {
                    string.append(char)
                    scanner.pop()
                }

                kind = .invalid(string)
            }
        }

        return Token(kind: kind, location: location ..< scanner.position)
    }

    mutating func peek(aheadBy n: Int = 0) -> Token? {
        if n < buffer.count { return buffer[n] }

        for _ in buffer.count...n {
            guard let token = next() else { return nil }
            buffer.append(token)
        }
        return buffer.last
    }

    @discardableResult
    mutating func pop() -> Token {
        if buffer.isEmpty {
            let token = next()!
            lastLocation = token.location
            return token
        }
        else {
            let token = buffer.removeFirst()
            lastLocation = token.location
            return token
        }
    }

    private mutating func consumeComment() -> String {
        assert(scanner.hasPrefix("//"))
        scanner.pop(2)

        var comment = ""
        while let char = scanner.peek(), char != "\n" {
            comment.append(char)
            scanner.pop()
        }

        assert(scanner.hasPrefix("\n"))
        scanner.pop()

        return comment
    }

    private mutating func consumeBlockComment() -> String {
        assert(scanner.hasPrefix("/*"))
        scanner.pop(2)

        var scalars: [UnicodeScalar] = []
        var depth = 1
        repeat {
            guard let scalar = scanner.peek() else {
                return ""
            }
            scalars.append(scalar)

            if scanner.hasPrefix("*/") { depth -= 1 }
            else if scanner.hasPrefix("/*") { depth += 1 }

            scanner.pop()
        } while depth > 0

        assert(scanner.peek() == "/")
        scanner.pop()

        scalars.removeLast()
        return String(scalars)
    }

    private mutating func skipWhitespace() {

        while let char = scanner.peek() {
            switch char {
            case _ where whitespace.contains(char):
                scanner.pop()

            default:
                return
            }
        }
    }
}

struct Token {
    let kind: Kind
    let location: SourceRange

    var start: SourceLocation {
        return location.lowerBound
    }

    var end: SourceLocation {
        return location.upperBound
    }
}

extension Token {

    enum Kind {
        case invalid(String)

        case comment(String)

        case ident(String)
        case integer(UInt64)
        case float(Double)
        case string(String)

        case newline

        // Structure
        case lparen
        case rparen
        case lbrace
        case rbrace
        case colon

        case dollar

        case equals
        case plus
        case minus
        case asterix
        case divide
        case ampersand

        // Punctuation
        case comma

        // Operators
        case lt
        case gt
        case lte
        case gte

        case returnArrow

        case keywordFn
        case keywordIf
        case keywordElse
        case keywordReturn

        case keywordStruct
    }
}

extension Token: Equatable {

    static func == (lhs: Token, rhs: Token) -> Bool {
        return lhs.kind == rhs.kind
    }
}

extension Token.Kind: Equatable {

    static func == (lhs: Token.Kind, rhs: Token.Kind) -> Bool {
        var (lhs, rhs) = (lhs, rhs)
        let lhsBytes = withUnsafeBytes(of: &lhs, { $0 })
        let rhsBytes = withUnsafeBytes(of: &rhs, { $0 })

        for (lbyte, rbyte) in zip(lhsBytes, rhsBytes) {
            guard lbyte == rbyte else { return false }
        }

        return true
    }
}

extension Token: CustomStringConvertible {

    var description: String {
        return kind.description
    }
}

extension Token.Kind: CustomStringConvertible {

    var description: String {
        switch self {
        case .invalid:
            return "<invalid>"

        case .comment(let comment):
            return "//" + comment

        case .ident(let string):
            return string

        case .float(let val):
            return val.description

        case .integer(let val):
            return val.description

        case .string(let val):
            return "\"" + val + "\""

        case .newline: return "\\n"
        case .lparen: return "("
        case .rparen: return ")"
        case .lbrace: return "{"
        case .rbrace: return "}"
        case .colon: return ":"
        case .dollar: return "$"
        case .equals: return "="
        case .plus: return "+"
        case .minus: return "-"
        case .asterix: return "*"
        case .divide: return "/"
        case .ampersand: return "&"
        case .comma: return ","
        case .lt: return "<"
        case .gt: return ">"
        case .lte: return "<="
        case .gte: return ">="
        case .returnArrow: return "->"
        case .keywordFn: return "fn"
        case .keywordIf: return "if"
        case .keywordElse: return "else"
        case .keywordReturn: return "return"
        case .keywordStruct: return "struct"
        }
    }
}

