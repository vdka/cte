
class AstNode: Hashable {

    var kind: AstKind
    var value: UnsafeMutableRawBufferPointer
    var tokens: [Token]

    init<T: AstNodeValue>(_ value: T, tokens: [Token]) {
        self.kind = T.astKind
        self.tokens = tokens

        let buffer = UnsafeMutableRawBufferPointer.allocate(count: MemoryLayout<T>.size)
        buffer.baseAddress!.assumingMemoryBound(to: T.self).initialize(to: value)

        self.value = buffer
    }

    var hashValue: Int {
        return Int(bitPattern: value.baseAddress!)
    }

    static func == (lhs: AstNode, rhs: AstNode) -> Bool {
        return lhs.tokens == rhs.tokens
    }
}

enum AstKind {
    case invalid
    case empty
    case identifier
    case litString
    case litNumber
    case function
    case polymorphicFunction
    case declaration
    case paren
    case prefix
    case infix
    case call
    case block
    case `if`
    case `return`
}

extension AstNode {
    static let empty = AstNode(AstNode.Empty(), tokens: [])
    static let invalid = AstNode(AstNode.Invalid(), tokens: [])
}


// MARK: AstValues

protocol AstNodeValue {
    static var astKind: AstKind { get }
}


extension AstNode {
    struct Invalid: AstNodeValue {
        static let astKind = AstKind.invalid
    }

    struct Empty: AstNodeValue {
        static let astKind = AstKind.empty
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
        let isCompileTime: Bool
    }

    struct Paren: AstNodeValue {
        static let astKind = AstKind.paren

        let expr: AstNode
    }

    struct Prefix: AstNodeValue {
        static let astKind = AstKind.prefix

        let kind: Token.Kind
        let expr: AstNode
    }

    struct Infix: AstNodeValue {
        static let astKind = AstKind.infix

        let kind: Token.Kind
        let lhs: AstNode
        let rhs: AstNode
    }

    struct Call: AstNodeValue {
        static let astKind = AstKind.call

        let callee: AstNode
        let arguments: [AstNode]
    }

    struct Block: AstNodeValue {
        static let astKind = AstKind.block

        let stmts: [AstNode]
    }

    struct If: AstNodeValue {
        static let astKind = AstKind.if

        let condition: AstNode
        let thenStmt: AstNode
        let elseStmt: AstNode?
    }

    struct Return: AstNodeValue {
        static let astKind = AstKind.return

        let value: AstNode
    }
}
