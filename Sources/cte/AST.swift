
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
    case comment
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
    case `for`
    case `switch`
    case `case`
    case `return`
    case compileTime
    case pointerType
    case functionType
    case `import`
    case library
    case foreign
}

extension AstNode {
    static let empty = AstNode(AstNode.Empty(), tokens: [])
    static let invalid = AstNode(AstNode.Invalid(), tokens: [])

    static func invalid(with tokens: [Token]) -> AstNode {
        return AstNode(AstNode.Invalid(), tokens: tokens)
    }
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

    struct Comment: AstValue {
        static let astKind = AstKind.comment

        let comment: String
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
        let isVariadic: Bool
    }

    struct FunctionType: AstValue {
        static let astKind = AstKind.functionType

        let parameters: [AstNode]
        let returnType: AstNode
        let isVariadic: Bool
    }

    struct PointerType: AstValue {
        static let astKind = AstKind.pointerType

        let pointee: AstNode
    }

    struct CompileTime: AstValue {
        static let astKind = AstKind.compileTime

        let stmt: AstNode
    }

    struct Declaration: AstValue {
        static let astKind = AstKind.declaration

        let identifier: AstNode
        let type: AstNode?
        let value: AstNode
        var isCompileTime: Bool
        var isForeign: Bool

        var linkName: String?
    }

    struct Paren: AstValue {
        static let astKind = AstKind.paren

        let expr: AstNode
    }

    struct Prefix: AstValue {
        static let astKind = AstKind.prefix

        let token: Token
        let expr: AstNode
    }

    struct Infix: AstValue {
        static let astKind = AstKind.infix

        let token: Token
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
        let arguments: [AstNode]
    }

    struct Block: AstValue {
        static let astKind = AstKind.block

        let stmts: [AstNode]
        var isForeign: Bool
    }

    struct If: AstValue {
        static let astKind = AstKind.if

        let condition: AstNode
        let thenStmt: AstNode
        let elseStmt: AstNode?
    }

    struct For: AstValue {
        static let astKind = AstKind.for

        let initializer: AstNode?
        let condition: AstNode?
        let step: AstNode?
        let body: AstNode
    }

    struct Switch: AstValue {
        static let astKind = AstKind.switch

        let subject: AstNode?
        let cases: [AstNode]
    }

    struct Case: AstValue {
        static let astKind = AstKind.case

        let condition: AstNode?
        let block: AstNode
    }

    struct Return: AstValue {
        static let astKind = AstKind.return

        let value: AstNode
    }

    struct Library: AstValue {
        static let astKind = AstKind.library

        let path: String
        let symbol: AstNode?
    }

    struct Import: AstValue {
        static let astKind = AstKind.import

        let path: String
        let symbol: AstNode?
        let includeSymbolsInParentScope: Bool
        let file: SourceFile
    }

    struct Foreign: AstValue {
        static let astKind = AstKind.foreign

        let library: AstNode
        let stmt: AstNode
    }
}

extension CommonDeclaration {

    var isFunction: Bool {
        return value.kind == .function || value.kind == .polymorphicFunction
    }
}
