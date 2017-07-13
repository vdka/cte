// Generated using Sourcery 0.7.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


extension AstNode {

    var asAssign: CommonAssign {
        get {
            assert(kind == AstNode.Assign.astKind)
            return value as! CommonAssign
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedAssign: AstNode.Assign {
        get {
            assert(kind == AstNode.Assign.astKind)
            return value as! AstNode.Assign
        }
        set {
            value = newValue
        }
    }

    var asBlock: CommonBlock {
        get {
            assert(kind == AstNode.Block.astKind)
            return value as! CommonBlock
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedBlock: AstNode.Block {
        get {
            assert(kind == AstNode.Block.astKind)
            return value as! AstNode.Block
        }
        set {
            value = newValue
        }
    }

    var asCall: CommonCall {
        get {
            assert(kind == AstNode.Call.astKind)
            return value as! CommonCall
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedCall: AstNode.Call {
        get {
            assert(kind == AstNode.Call.astKind)
            return value as! AstNode.Call
        }
        set {
            value = newValue
        }
    }

    var asCase: CommonCase {
        get {
            assert(kind == AstNode.Case.astKind)
            return value as! CommonCase
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedCase: AstNode.Case {
        get {
            assert(kind == AstNode.Case.astKind)
            return value as! AstNode.Case
        }
        set {
            value = newValue
        }
    }

    var asComment: CommonComment {
        get {
            assert(kind == AstNode.Comment.astKind)
            return value as! CommonComment
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedComment: AstNode.Comment {
        get {
            assert(kind == AstNode.Comment.astKind)
            return value as! AstNode.Comment
        }
        set {
            value = newValue
        }
    }

    var asCompileTime: CommonCompileTime {
        get {
            assert(kind == AstNode.CompileTime.astKind)
            return value as! CommonCompileTime
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedCompileTime: AstNode.CompileTime {
        get {
            assert(kind == AstNode.CompileTime.astKind)
            return value as! AstNode.CompileTime
        }
        set {
            value = newValue
        }
    }

    var asDeclaration: CommonDeclaration {
        get {
            assert(kind == AstNode.Declaration.astKind)
            return value as! CommonDeclaration
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedDeclaration: AstNode.Declaration {
        get {
            assert(kind == AstNode.Declaration.astKind)
            return value as! AstNode.Declaration
        }
        set {
            value = newValue
        }
    }

    var asEmpty: CommonEmpty {
        get {
            assert(kind == AstNode.Empty.astKind)
            return value as! CommonEmpty
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedEmpty: AstNode.Empty {
        get {
            assert(kind == AstNode.Empty.astKind)
            return value as! AstNode.Empty
        }
        set {
            value = newValue
        }
    }

    var asFloatLiteral: CommonFloatLiteral {
        get {
            assert(kind == AstNode.FloatLiteral.astKind)
            return value as! CommonFloatLiteral
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedFloatLiteral: AstNode.FloatLiteral {
        get {
            assert(kind == AstNode.FloatLiteral.astKind)
            return value as! AstNode.FloatLiteral
        }
        set {
            value = newValue
        }
    }

    var asFor: CommonFor {
        get {
            assert(kind == AstNode.For.astKind)
            return value as! CommonFor
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedFor: AstNode.For {
        get {
            assert(kind == AstNode.For.astKind)
            return value as! AstNode.For
        }
        set {
            value = newValue
        }
    }

    var asForeign: CommonForeign {
        get {
            assert(kind == AstNode.Foreign.astKind)
            return value as! CommonForeign
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedForeign: AstNode.Foreign {
        get {
            assert(kind == AstNode.Foreign.astKind)
            return value as! AstNode.Foreign
        }
        set {
            value = newValue
        }
    }

    var asFunction: CommonFunction {
        get {
            assert(kind == AstNode.Function.astKind)
            return value as! CommonFunction
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedFunction: AstNode.Function {
        get {
            assert(kind == AstNode.Function.astKind)
            return value as! AstNode.Function
        }
        set {
            value = newValue
        }
    }

    var asFunctionType: CommonFunctionType {
        get {
            assert(kind == AstNode.FunctionType.astKind)
            return value as! CommonFunctionType
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedFunctionType: AstNode.FunctionType {
        get {
            assert(kind == AstNode.FunctionType.astKind)
            return value as! AstNode.FunctionType
        }
        set {
            value = newValue
        }
    }

    var asIdentifier: CommonIdentifier {
        get {
            assert(kind == AstNode.Identifier.astKind)
            return value as! CommonIdentifier
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedIdentifier: AstNode.Identifier {
        get {
            assert(kind == AstNode.Identifier.astKind)
            return value as! AstNode.Identifier
        }
        set {
            value = newValue
        }
    }

    var asIf: CommonIf {
        get {
            assert(kind == AstNode.If.astKind)
            return value as! CommonIf
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedIf: AstNode.If {
        get {
            assert(kind == AstNode.If.astKind)
            return value as! AstNode.If
        }
        set {
            value = newValue
        }
    }

    var asImport: CommonImport {
        get {
            assert(kind == AstNode.Import.astKind)
            return value as! CommonImport
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedImport: AstNode.Import {
        get {
            assert(kind == AstNode.Import.astKind)
            return value as! AstNode.Import
        }
        set {
            value = newValue
        }
    }

    var asInfix: CommonInfix {
        get {
            assert(kind == AstNode.Infix.astKind)
            return value as! CommonInfix
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedInfix: AstNode.Infix {
        get {
            assert(kind == AstNode.Infix.astKind)
            return value as! AstNode.Infix
        }
        set {
            value = newValue
        }
    }

    var asIntegerLiteral: CommonIntegerLiteral {
        get {
            assert(kind == AstNode.IntegerLiteral.astKind)
            return value as! CommonIntegerLiteral
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedIntegerLiteral: AstNode.IntegerLiteral {
        get {
            assert(kind == AstNode.IntegerLiteral.astKind)
            return value as! AstNode.IntegerLiteral
        }
        set {
            value = newValue
        }
    }

    var asInvalid: CommonInvalid {
        get {
            assert(kind == AstNode.Invalid.astKind)
            return value as! CommonInvalid
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedInvalid: AstNode.Invalid {
        get {
            assert(kind == AstNode.Invalid.astKind)
            return value as! AstNode.Invalid
        }
        set {
            value = newValue
        }
    }

    var asLibrary: CommonLibrary {
        get {
            assert(kind == AstNode.Library.astKind)
            return value as! CommonLibrary
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedLibrary: AstNode.Library {
        get {
            assert(kind == AstNode.Library.astKind)
            return value as! AstNode.Library
        }
        set {
            value = newValue
        }
    }

    var asList: CommonList {
        get {
            assert(kind == AstNode.List.astKind)
            return value as! CommonList
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedList: AstNode.List {
        get {
            assert(kind == AstNode.List.astKind)
            return value as! AstNode.List
        }
        set {
            value = newValue
        }
    }

    var asMemberAccess: CommonMemberAccess {
        get {
            assert(kind == AstNode.MemberAccess.astKind)
            return value as! CommonMemberAccess
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedMemberAccess: AstNode.MemberAccess {
        get {
            assert(kind == AstNode.MemberAccess.astKind)
            return value as! AstNode.MemberAccess
        }
        set {
            value = newValue
        }
    }

    var asParameter: CommonParameter {
        get {
            assert(kind == AstNode.Parameter.astKind)
            return value as! CommonParameter
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedParameter: AstNode.Parameter {
        get {
            assert(kind == AstNode.Parameter.astKind)
            return value as! AstNode.Parameter
        }
        set {
            value = newValue
        }
    }

    var asParen: CommonParen {
        get {
            assert(kind == AstNode.Paren.astKind)
            return value as! CommonParen
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedParen: AstNode.Paren {
        get {
            assert(kind == AstNode.Paren.astKind)
            return value as! AstNode.Paren
        }
        set {
            value = newValue
        }
    }

    var asPointerType: CommonPointerType {
        get {
            assert(kind == AstNode.PointerType.astKind)
            return value as! CommonPointerType
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedPointerType: AstNode.PointerType {
        get {
            assert(kind == AstNode.PointerType.astKind)
            return value as! AstNode.PointerType
        }
        set {
            value = newValue
        }
    }

    var asPrefix: CommonPrefix {
        get {
            assert(kind == AstNode.Prefix.astKind)
            return value as! CommonPrefix
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedPrefix: AstNode.Prefix {
        get {
            assert(kind == AstNode.Prefix.astKind)
            return value as! AstNode.Prefix
        }
        set {
            value = newValue
        }
    }

    var asReturn: CommonReturn {
        get {
            assert(kind == AstNode.Return.astKind)
            return value as! CommonReturn
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedReturn: AstNode.Return {
        get {
            assert(kind == AstNode.Return.astKind)
            return value as! AstNode.Return
        }
        set {
            value = newValue
        }
    }

    var asStringLiteral: CommonStringLiteral {
        get {
            assert(kind == AstNode.StringLiteral.astKind)
            return value as! CommonStringLiteral
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedStringLiteral: AstNode.StringLiteral {
        get {
            assert(kind == AstNode.StringLiteral.astKind)
            return value as! AstNode.StringLiteral
        }
        set {
            value = newValue
        }
    }

    var asSwitch: CommonSwitch {
        get {
            assert(kind == AstNode.Switch.astKind)
            return value as! CommonSwitch
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedSwitch: AstNode.Switch {
        get {
            assert(kind == AstNode.Switch.astKind)
            return value as! AstNode.Switch
        }
        set {
            value = newValue
        }
    }

    var asVariadic: CommonVariadic {
        get {
            assert(kind == AstNode.Variadic.astKind)
            return value as! CommonVariadic
        }
        set {
            self.value = newValue
        }
    }
    var asUncheckedVariadic: AstNode.Variadic {
        get {
            assert(kind == AstNode.Variadic.astKind)
            return value as! AstNode.Variadic
        }
        set {
            value = newValue
        }
    }

    var asCheckedBlock: Checker.Block {
        get {
            assert(kind == Checker.Block.astKind)
            return value as! Checker.Block
        }
        set {
            value = newValue
        }
    }

    var asCheckedCall: Checker.Call {
        get {
            assert(kind == Checker.Call.astKind)
            return value as! Checker.Call
        }
        set {
            value = newValue
        }
    }

    var asCheckedCase: Checker.Case {
        get {
            assert(kind == Checker.Case.astKind)
            return value as! Checker.Case
        }
        set {
            value = newValue
        }
    }

    var asCheckedCast: Checker.Cast {
        get {
            assert(kind == Checker.Cast.astKind)
            return value as! Checker.Cast
        }
        set {
            value = newValue
        }
    }

    var asCheckedDeclaration: Checker.Declaration {
        get {
            assert(kind == Checker.Declaration.astKind)
            return value as! Checker.Declaration
        }
        set {
            value = newValue
        }
    }

    var asCheckedFloatLiteral: Checker.FloatLiteral {
        get {
            assert(kind == Checker.FloatLiteral.astKind)
            return value as! Checker.FloatLiteral
        }
        set {
            value = newValue
        }
    }

    var asCheckedFunction: Checker.Function {
        get {
            assert(kind == Checker.Function.astKind)
            return value as! Checker.Function
        }
        set {
            value = newValue
        }
    }

    var asCheckedFunctionType: Checker.FunctionType {
        get {
            assert(kind == Checker.FunctionType.astKind)
            return value as! Checker.FunctionType
        }
        set {
            value = newValue
        }
    }

    var asCheckedIdentifier: Checker.Identifier {
        get {
            assert(kind == Checker.Identifier.astKind)
            return value as! Checker.Identifier
        }
        set {
            value = newValue
        }
    }

    var asCheckedInfix: Checker.Infix {
        get {
            assert(kind == Checker.Infix.astKind)
            return value as! Checker.Infix
        }
        set {
            value = newValue
        }
    }

    var asCheckedIntegerLiteral: Checker.IntegerLiteral {
        get {
            assert(kind == Checker.IntegerLiteral.astKind)
            return value as! Checker.IntegerLiteral
        }
        set {
            value = newValue
        }
    }

    var asCheckedMemberAccess: Checker.MemberAccess {
        get {
            assert(kind == Checker.MemberAccess.astKind)
            return value as! Checker.MemberAccess
        }
        set {
            value = newValue
        }
    }

    var asCheckedParameter: Checker.Parameter {
        get {
            assert(kind == Checker.Parameter.astKind)
            return value as! Checker.Parameter
        }
        set {
            value = newValue
        }
    }

    var asCheckedParen: Checker.Paren {
        get {
            assert(kind == Checker.Paren.astKind)
            return value as! Checker.Paren
        }
        set {
            value = newValue
        }
    }

    var asCheckedPointerType: Checker.PointerType {
        get {
            assert(kind == Checker.PointerType.astKind)
            return value as! Checker.PointerType
        }
        set {
            value = newValue
        }
    }

    var asCheckedPolymorphicFunction: Checker.PolymorphicFunction {
        get {
            assert(kind == Checker.PolymorphicFunction.astKind)
            return value as! Checker.PolymorphicFunction
        }
        set {
            value = newValue
        }
    }

    var asCheckedPrefix: Checker.Prefix {
        get {
            assert(kind == Checker.Prefix.astKind)
            return value as! Checker.Prefix
        }
        set {
            value = newValue
        }
    }

    var asCheckedStringLiteral: Checker.StringLiteral {
        get {
            assert(kind == Checker.StringLiteral.astKind)
            return value as! Checker.StringLiteral
        }
        set {
            value = newValue
        }
    }
}


protocol CommonAssign: AstValue {

    var lvalues: [AstNode] { get }
    var rvalues: [AstNode] { get }
}

protocol CommonBlock: AstValue {

    var stmts: [AstNode] { get }
    var isForeign: Bool { get set }
}

protocol CommonCall: AstValue {

    var callee: AstNode { get }
    var arguments: [AstNode] { get }
}

protocol CommonCase: AstValue {

    var condition: AstNode? { get }
    var block: AstNode { get }
}

protocol CommonComment: AstValue {

    var comment: String { get }
}

protocol CommonCompileTime: AstValue {

    var stmt: AstNode { get }
}

protocol CommonDeclaration: AstValue {

    var names: [AstNode] { get set }
    var type: AstNode? { get set }
    var values: [AstNode] { get set }
    var linkName: String? { get set }
    var flags: DeclarationFlags { get set }
}

protocol CommonEmpty: AstValue {

}

protocol CommonFloatLiteral: AstValue {

    var value: Double { get }
}

protocol CommonFor: AstValue {

    var initializer: AstNode? { get }
    var condition: AstNode? { get }
    var step: AstNode? { get }
    var body: AstNode { get }
}

protocol CommonForeign: AstValue {

    var library: AstNode { get }
    var stmt: AstNode { get }
}

protocol CommonFunction: AstValue {

    var parameters: [AstNode] { get set }
    var returnTypes: [AstNode] { get set }
    var body: AstNode { get }
    var flags: FunctionFlags { get set }
}

protocol CommonFunctionType: AstValue {

    var parameters: [AstNode] { get }
    var returnTypes: [AstNode] { get }
    var flags: FunctionFlags { get set }
}

protocol CommonIdentifier: AstValue {

    var name: String { get }
}

protocol CommonIf: AstValue {

    var condition: AstNode { get }
    var thenStmt: AstNode { get }
    var elseStmt: AstNode? { get }
}

protocol CommonImport: AstValue {

    var path: String { get }
    var symbol: AstNode? { get }
    var includeSymbolsInParentScope: Bool { get }
    var file: SourceFile { get }
}

protocol CommonInfix: AstValue {

    var token: Token { get }
    var lhs: AstNode { get }
    var rhs: AstNode { get }
}

protocol CommonIntegerLiteral: AstValue {

    var value: UInt64 { get }
}

protocol CommonInvalid: AstValue {

}

protocol CommonLibrary: AstValue {

    var path: String { get }
    var symbol: AstNode? { get }
}

protocol CommonList: AstValue {

    var values: [AstNode] { get }
}

protocol CommonMemberAccess: AstValue {

    var aggregate: AstNode { get }
    var member: AstNode { get }
    var memberName: String { get }
}

protocol CommonParameter: AstValue {

    var name: AstNode { get set }
    var type: AstNode { get set }
}

protocol CommonParen: AstValue {

    var expr: AstNode { get }
}

protocol CommonPointerType: AstValue {

    var pointee: AstNode { get }
}

protocol CommonPrefix: AstValue {

    var token: Token { get }
    var expr: AstNode { get }
}

protocol CommonReturn: AstValue {

    var values: [AstNode] { get }
}

protocol CommonStringLiteral: AstValue {

    var value: String { get }
}

protocol CommonSwitch: AstValue {

    var subject: AstNode? { get }
    var cases: [AstNode] { get }
}

protocol CommonVariadic: AstValue {

    var type: AstNode { get }
    var cCompatible: Bool { get set }
}

extension AstNode.Assign: CommonAssign {}
extension AstNode.Block: CommonBlock {}
extension AstNode.Call: CommonCall {}
extension AstNode.Case: CommonCase {}
extension AstNode.Comment: CommonComment {}
extension AstNode.CompileTime: CommonCompileTime {}
extension AstNode.Declaration: CommonDeclaration {}
extension AstNode.Empty: CommonEmpty {}
extension AstNode.FloatLiteral: CommonFloatLiteral {}
extension AstNode.For: CommonFor {}
extension AstNode.Foreign: CommonForeign {}
extension AstNode.Function: CommonFunction {}
extension AstNode.FunctionType: CommonFunctionType {}
extension AstNode.Identifier: CommonIdentifier {}
extension AstNode.If: CommonIf {}
extension AstNode.Import: CommonImport {}
extension AstNode.Infix: CommonInfix {}
extension AstNode.IntegerLiteral: CommonIntegerLiteral {}
extension AstNode.Invalid: CommonInvalid {}
extension AstNode.Library: CommonLibrary {}
extension AstNode.List: CommonList {}
extension AstNode.MemberAccess: CommonMemberAccess {}
extension AstNode.Parameter: CommonParameter {}
extension AstNode.Paren: CommonParen {}
extension AstNode.PointerType: CommonPointerType {}
extension AstNode.Prefix: CommonPrefix {}
extension AstNode.Return: CommonReturn {}
extension AstNode.StringLiteral: CommonStringLiteral {}
extension AstNode.Switch: CommonSwitch {}
extension AstNode.Variadic: CommonVariadic {}
extension Checker.Block: CommonBlock {}
extension Checker.Call: CommonCall {}
extension Checker.Case: CommonCase {}
extension Checker.Declaration: CommonDeclaration {}
extension Checker.FloatLiteral: CommonFloatLiteral {}
extension Checker.Function: CommonFunction {}
extension Checker.FunctionType: CommonFunctionType {}
extension Checker.Identifier: CommonIdentifier {}
extension Checker.Infix: CommonInfix {}
extension Checker.IntegerLiteral: CommonIntegerLiteral {}
extension Checker.MemberAccess: CommonMemberAccess {}
extension Checker.Parameter: CommonParameter {}
extension Checker.Paren: CommonParen {}
extension Checker.PointerType: CommonPointerType {}
extension Checker.Prefix: CommonPrefix {}
extension Checker.StringLiteral: CommonStringLiteral {}

extension Type {

    var asAny: Type.`Any` {
        return value as! Type.`Any`
    }

    var asBoolean: Type.Boolean {
        return value as! Type.Boolean
    }

    var asCVargsAny: Type.CVargsAny {
        return value as! Type.CVargsAny
    }

    var asFile: Type.File {
        return value as! Type.File
    }

    var asFloatingPoint: Type.FloatingPoint {
        return value as! Type.FloatingPoint
    }

    var asFunction: Type.Function {
        return value as! Type.Function
    }

    var asInteger: Type.Integer {
        return value as! Type.Integer
    }

    var asMetatype: Type.Metatype {
        return value as! Type.Metatype
    }

    var asPointer: Type.Pointer {
        return value as! Type.Pointer
    }

    var asPolymorphic: Type.Polymorphic {
        return value as! Type.Polymorphic
    }

    var asTuple: Type.Tuple {
        return value as! Type.Tuple
    }

    var asVoid: Type.Void {
        return value as! Type.Void
    }
}
