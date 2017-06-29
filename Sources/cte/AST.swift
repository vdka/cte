
class AstNode: Hashable {

    var kind: AstKind {
        return type(of: value).astKind
    }
    var value: AstValue
    var tokens: [Token]

    init<T: AstValue>(_ value: T, tokens: [Token]) {
        self.value = value
        self.tokens = tokens
    }

    init(value: AstValue, tokens: [Token]) {
        self.value = value
        self.tokens = tokens
    }

    var hashValue: Int {
        return unsafeBitCast(self, to: Int.self) // classes are just pointers after all
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
    case litFloat
    case litInteger
    case function
    case polymorphicFunction
    case declaration
    case paren
    case prefix
    case infix
    case assign
    case call
    case cast
    case block
    case `if`
    case `return`
    case pointerType
    case functionType
}

extension AstNode {
    static let empty = AstNode(AstNode.Empty(), tokens: [])
    static let invalid = AstNode(AstNode.Invalid(), tokens: [])
}


// MARK: AstValues

protocol AstValue {
    static var astKind: AstKind { get }
}


extension AstNode {
    struct Invalid: AstValue {
        static let astKind = AstKind.invalid
    }

    struct Empty: AstValue {
        static let astKind = AstKind.empty
    }

    struct Identifier: AstValue {
        static let astKind = AstKind.identifier

        let name: String
    }

    struct StringLiteral: AstValue {
        static let astKind = AstKind.litString

        let value: String
    }

    struct FloatLiteral: AstValue {
        static let astKind = AstKind.litFloat

        let value: Double
    }

    struct IntegerLiteral: AstValue {
        static let astKind = AstKind.litInteger

        // NOTE(vdka): Negation is handled through a prefix op
        let value: UInt64
    }

    struct Function: AstValue {
        static let astKind = AstKind.function

        var parameters: [AstNode]
        var returnType: AstNode
        let body: AstNode
    }

    struct FunctionType: AstValue {
        static let astKind = AstKind.functionType

        let parameters: [AstNode]
        let returnType: AstNode
    }

    struct PointerType: AstValue {
        static let astKind = AstKind.pointerType

        let pointee: AstNode
    }

    struct Declaration: AstValue {
        static let astKind = AstKind.declaration

        let identifier: AstNode
        let type: AstNode?
        let value: AstNode
        let isCompileTime: Bool

        var isFunction: Bool {
            return value.kind == .function || value.kind == .polymorphicFunction
        }
    }

    struct Paren: AstValue {
        static let astKind = AstKind.paren

        let expr: AstNode
    }

    struct Prefix: AstValue {
        static let astKind = AstKind.prefix

        let kind: Token.Kind
        let expr: AstNode
    }

    struct Infix: AstValue {
        static let astKind = AstKind.infix

        let kind: Token.Kind
        let lhs: AstNode
        let rhs: AstNode
    }

    struct Assign: AstValue {
        static let astKind = AstKind.assign

        let lvalue: AstNode
        let rvalue: AstNode
    }

    struct Call: AstValue {
        static let astKind = AstKind.call

        let callee: AstNode
        var arguments: [AstNode]
    }

    struct Block: AstValue {
        static let astKind = AstKind.block

        let stmts: [AstNode]
    }

    struct If: AstValue {
        static let astKind = AstKind.if

        let condition: AstNode
        let thenStmt: AstNode
        let elseStmt: AstNode?
    }

    struct Return: AstValue {
        static let astKind = AstKind.return

        let value: AstNode
    }
}
