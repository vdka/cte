
struct AstNode: Hashable {

    var kind: AstKind
    var value: UnsafeMutableRawPointer
    var tokens: [Token]

    init<T: AstNodeValue>(_ value: T, tokens: [Token]) {
        self.kind = T.astKind
        self.tokens = tokens

        let pointer = UnsafeMutableRawPointer.allocate(bytes: maxBytesForNodeValue, alignedTo: 8)
        pointer.assumingMemoryBound(to: T.self).initialize(to: value)

        self.value = pointer
    }

    struct Value {
        var node: AstNode
    }

    var hashValue: Int {
        return Int(bitPattern: value)
    }

    static func == (lhs: AstNode, rhs: AstNode) -> Bool {
        return lhs.tokens == rhs.tokens
    }
}

enum AstKind {
    case invalid
    case list
    case empty
    case identifier
    case litString
    case litNumber
    case compiletime
    case function
    case declaration
    case exprParen
    case exprUnary
    case exprBinary
    case exprCall
    case stmtBlock
    case stmtIf
    case stmtReturn
}

extension AstNode {
    static let empty = AstNode(Empty(), tokens: [])
    static let invalid = AstNode(Invalid(), tokens: [])
}

extension AstNode {

    var val: Value {
        get {
            return Value(node: self)
        }
        set {} // allows mutability
    }
}


// MARK: AstValues

protocol AstNodeValue {
    static var astKind: AstKind { get }
}


struct Invalid: AstNodeValue {
    static let astKind = AstKind.invalid
}

struct Empty: AstNodeValue {
    static let astKind = AstKind.empty
}

struct List: AstNodeValue {
    static let astKind = AstKind.list

    let exprs: [AstNode]
}

struct Identifier: AstNodeValue {
    static let astKind = AstKind.identifier

    let name: String
}

struct StringLiteral: AstNodeValue {
    static let astKind = AstKind.litString

    let value: String
}

struct NumberLiteral: AstNodeValue {
    static let astKind = AstKind.litNumber

    let value: Double
}

struct CompileTime: AstNodeValue {
    static let astKind = AstKind.compiletime

    let stmt: AstNode
}

struct Function: AstNodeValue {
    static let astKind = AstKind.function

    let parameters: [AstNode]
    let returnType: AstNode
    let body: AstNode
}

struct Declaration: AstNodeValue {
    static let astKind = AstKind.declaration

    let identifier: AstNode
    let type: AstNode?
    let value: AstNode
}

struct ExprParen: AstNodeValue {
    static let astKind = AstKind.exprParen

    let expr: AstNode
}

struct ExprUnary: AstNodeValue {
    static let astKind = AstKind.exprUnary

    let kind: Token.Kind
    let expr: AstNode
}

struct ExprBinary: AstNodeValue {
    static let astKind = AstKind.exprBinary

    let kind: Token.Kind
    let lhs: AstNode
    let rhs: AstNode
}

struct ExprCall: AstNodeValue {
    static let astKind = AstKind.exprCall

    let callee: AstNode
    let arguments: [AstNode]
}

struct StmtBlock: AstNodeValue {
    static let astKind = AstKind.stmtBlock

    let stmts: [AstNode]
}

struct StmtIf: AstNodeValue {
    static let astKind = AstKind.stmtIf

    let condition: AstNode
    let thenStmt: AstNode
    let elseStmt: AstNode?
}

struct StmtReturn: AstNodeValue {
    static let astKind = AstKind.stmtReturn

    let value: AstNode
}

