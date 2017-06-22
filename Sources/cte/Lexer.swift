
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

                var string = ""
                while let char = scanner.peek(), (identChars + digits + [".", "-"]).contains(char) {
                    string.append(char)
                    scanner.pop()
                }

                if let val = Double(string) {
                    kind = .number(val)
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

        case ident(String)
        case number(Double)
        case string(String)

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

        case .ident(let string):
            return string

        case .number(let val):
            return val.description

        case .string(let val):
            return "\"" + val + "\""

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

