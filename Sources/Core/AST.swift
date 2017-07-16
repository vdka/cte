
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
    case list
    case comment
    case identifier
    case litString
    case litFloat
    case litInteger
    case function
    case polymorphicFunction
    case parameter
    case variadic
    case declaration
    case paren
    case prefix
    case infix
    case assign
    case call
    case cast
    case memberAccess
    case block
    case `if`
    case `for`
    case `switch`
    case `case`
    case `return`
    case `break`
    case `continue`
    case `fallthrough`
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

    struct List: AstValue {
        static let astKind = AstKind.list

        let values: [AstNode]
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
        var returnTypes: [AstNode]
        let body: AstNode

        var flags: FunctionFlags
    }

    struct Parameter: AstValue {
        static let astKind = AstKind.parameter

        var name: AstNode
        var type: AstNode
    }

    struct FunctionType: AstValue {
        static let astKind = AstKind.functionType

        let parameters: [AstNode]
        let returnTypes: [AstNode]
        var flags: FunctionFlags
    }

    struct Variadic: AstValue {
        static let astKind = AstKind.variadic

        let type: AstNode
        var cCompatible: Bool
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

        var names: [AstNode]
        var type: AstNode?
        var values: [AstNode]

        var linkName: String?
        var flags: DeclarationFlags
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

        let lvalues: [AstNode]
        let rvalues: [AstNode]
    }

    struct Call: AstValue {
        static let astKind = AstKind.call

        let callee: AstNode
        let arguments: [AstNode]
    }

    struct MemberAccess: AstValue {
        static let astKind = AstKind.memberAccess

        let aggregate: AstNode
        let member: AstNode

        var memberName: String {
            return member.asIdentifier.name
        }
    }

    struct Block: AstValue {
        static let astKind = AstKind.block

        let stmts: [AstNode]
        var isForeign: Bool
        var isFunction: Bool
    }

    struct If: AstValue {
        static let astKind = AstKind.if

        let condition: AstNode
        let thenStmt: AstNode
        let elseStmt: AstNode?
    }

    struct For: AstValue {
        static let astKind = AstKind.for

        var label: AstNode?
        let initializer: AstNode?
        let condition: AstNode?
        let step: AstNode?
        let body: AstNode
    }

    struct Switch: AstValue {
        static let astKind = AstKind.switch

        var label: AstNode?
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

        let values: [AstNode]
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

    struct Break: AstValue {
        static let astKind = AstKind.break

        let label: AstNode?
    }

    struct Continue: AstValue {
        static let astKind = AstKind.continue

        let label: AstNode?
    }

    struct Fallthrough: AstValue {
        static let astKind = AstKind.fallthrough
    }
}

struct DeclarationFlags: OptionSet {
    var rawValue: UInt8

    static let compileTime  = DeclarationFlags(rawValue: 0b0000_0001)
    static let foreign      = DeclarationFlags(rawValue: 0b0000_0010)
}

struct FunctionFlags: OptionSet {
    var rawValue: UInt8

    static let variadic          = FunctionFlags(rawValue: 0b0000_0001)
    static let discardableResult = FunctionFlags(rawValue: 0b0000_0010)
    static let specialization    = FunctionFlags(rawValue: 0b0000_0100)
    static let cVariadic         = FunctionFlags(rawValue: 0b1000_0001) // implies variadic
}

extension CommonDeclaration {

    var isFunction: Bool {
        return values.first?.kind == .function || values.first?.kind == .polymorphicFunction
    }

    var isFunctionType: Bool {
        return values.first?.kind == .functionType
    }
}