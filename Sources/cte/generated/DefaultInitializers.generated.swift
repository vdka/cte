// Generated using Sourcery 0.7.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



extension AstNode {

    init(value: AstValue,tokens: [Token]) {
        self.value = value
        self.tokens = tokens
    }
}

extension AstNode.Block {

    init(stmts: [AstNode]) {
        self.stmts = stmts
    }
}

extension AstNode.Call {

    init(callee: AstNode,arguments: [AstNode]) {
        self.callee = callee
        self.arguments = arguments
    }
}

extension AstNode.Declaration {

    init(identifier: AstNode,type: AstNode?,value: AstNode,isCompileTime: Bool) {
        self.identifier = identifier
        self.type = type
        self.value = value
        self.isCompileTime = isCompileTime
    }
}

extension AstNode.Empty {

    init() {
    }
}

extension AstNode.FloatLiteral {

    init(value: Double) {
        self.value = value
    }
}

extension AstNode.Function {

    init(parameters: [AstNode],returnType: AstNode,body: AstNode) {
        self.parameters = parameters
        self.returnType = returnType
        self.body = body
    }
}

extension AstNode.Identifier {

    init(name: String) {
        self.name = name
    }
}

extension AstNode.If {

    init(condition: AstNode,thenStmt: AstNode,elseStmt: AstNode?) {
        self.condition = condition
        self.thenStmt = thenStmt
        self.elseStmt = elseStmt
    }
}

extension AstNode.Infix {

    init(kind: Token.Kind,lhs: AstNode,rhs: AstNode) {
        self.kind = kind
        self.lhs = lhs
        self.rhs = rhs
    }
}

extension AstNode.IntegerLiteral {

    init(value: UInt64) {
        self.value = value
    }
}

extension AstNode.Invalid {

    init() {
    }
}

extension AstNode.Paren {

    init(expr: AstNode) {
        self.expr = expr
    }
}

extension AstNode.PointerType {

    init(pointee: AstNode) {
        self.pointee = pointee
    }
}

extension AstNode.Prefix {

    init(kind: Token.Kind,expr: AstNode) {
        self.kind = kind
        self.expr = expr
    }
}

extension AstNode.Return {

    init(value: AstNode) {
        self.value = value
    }
}

extension AstNode.StringLiteral {

    init(value: String) {
        self.value = value
    }
}

extension BidirectionalCollection {

    init() {
    }
}

extension BufferedScanner {

    init(iterator: AnyIterator<Element>,buffer: [Element]) {
        self.iterator = iterator
        self.buffer = buffer
    }
}

extension BuiltinType {

    init(entity: Entity,type: Type) {
        self.entity = entity
        self.type = type
    }
}

extension Checker {

    init(nodes: [AstNode],currentScope: Scope,currentExpectedReturnType: Type?) {
        self.nodes = nodes
        self.currentScope = currentScope
        self.currentExpectedReturnType = currentExpectedReturnType
    }
}

extension Checker.Block {

    init(stmts: [AstNode],scope: Scope) {
        self.stmts = stmts
        self.scope = scope
    }
}

extension Checker.Call {

    init(callee: AstNode,arguments: [AstNode],isSpecialized: Bool,type: Type) {
        self.callee = callee
        self.arguments = arguments
        self.isSpecialized = isSpecialized
        self.type = type
    }
}

extension Checker.Declaration {

    init(identifier: AstNode,type: AstNode?,value: AstNode,isCompileTime: Bool,entity: Entity) {
        self.identifier = identifier
        self.type = type
        self.value = value
        self.isCompileTime = isCompileTime
        self.entity = entity
    }
}

extension Checker.FloatLiteral {

    init(value: Double,type: Type) {
        self.value = value
        self.type = type
    }
}

extension Checker.Function {

    init(parameters: [AstNode],returnType: AstNode,body: AstNode,scope: Scope,type: Type) {
        self.parameters = parameters
        self.returnType = returnType
        self.body = body
        self.scope = scope
        self.type = type
    }
}

extension Checker.Identifier {

    init(name: String,entity: Entity) {
        self.name = name
        self.entity = entity
    }
}

extension Checker.Infix {

    init(kind: Token.Kind,lhs: AstNode,rhs: AstNode,type: Type,op: OpCode.Binary,lhsCast: OpCode.Cast?,rhsCast: OpCode.Cast?) {
        self.kind = kind
        self.lhs = lhs
        self.rhs = rhs
        self.type = type
        self.op = op
        self.lhsCast = lhsCast
        self.rhsCast = rhsCast
    }
}

extension Checker.IntegerLiteral {

    init(value: UInt64,type: Type) {
        self.value = value
        self.type = type
    }
}

extension Checker.Paren {

    init(expr: AstNode,type: Type) {
        self.expr = expr
        self.type = type
    }
}

extension Checker.PointerType {

    init(pointee: AstNode,type: Type) {
        self.pointee = pointee
        self.type = type
    }
}

extension Checker.PolymorphicFunction {

    init(parameters: [AstNode],returnType: AstNode,body: AstNode,type: Type,specializations: [(specializedTypes: [Type], strippedType: Type)]) {
        self.parameters = parameters
        self.returnType = returnType
        self.body = body
        self.type = type
        self.specializations = specializations
    }
}

extension Checker.Prefix {

    init(kind: Token.Kind,expr: AstNode,type: Type) {
        self.kind = kind
        self.expr = expr
        self.type = type
    }
}

extension Checker.StringLiteral {

    init(value: String,type: Type) {
        self.value = value
        self.type = type
    }
}

extension Collection {

    init() {
    }
}

extension Entity {

    init(ident: Token,type: Type?,flags: Flag,value: IRValue?,specializations: [([Type], Function)]?) {
        self.ident = ident
        self.type = type
        self.flags = flags
        self.value = value
        self.specializations = specializations
    }
}

extension Entity.Flag {

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

extension ExpressibleByStringLiteral {

    init() {
    }
}

extension File {

    init(path: String,data: String) {
        self.path = path
        self.data = data
    }
}

extension FileManager {

    init() {
    }
}

extension FileScanner {

    init(file: File,position: SourceLocation,scanner: BufferedScanner<UnicodeScalar>) {
        self.file = file
        self.position = position
        self.scanner = scanner
    }
}

extension IRGenerator {

    init(nodes: [AstNode],module: Module,builder: IRBuilder,mainFunction: Function) {
        self.nodes = nodes
        self.module = module
        self.builder = builder
        self.mainFunction = mainFunction
    }
}

extension InfixOperator {

    init(symbol: Token.Kind,lbp: UInt8,associativity: Associativity,led: ((inout Parser, AstNode) -> AstNode)) {
        self.symbol = symbol
        self.lbp = lbp
        self.associativity = associativity
        self.led = led
    }
}

extension Lexer {

    init(scanner: FileScanner,buffer: [Token],lastLocation: SourceRange) {
        self.scanner = scanner
        self.buffer = buffer
        self.lastLocation = lastLocation
    }
}

extension Parser {

    init(lexer: Lexer,state: State) {
        self.lexer = lexer
        self.state = state
    }
}

extension Parser.State {

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

extension PrefixOperator {

    init(symbol: Token.Kind,nud: ((inout Parser) -> AstNode)) {
        self.symbol = symbol
        self.nud = nud
    }
}

extension Queue {

    init(array: [T]) {
        self.array = array
    }
}

extension Range {

    init() {
    }
}

extension Scope {

    init(parent: Scope?,members: [Entity]) {
        self.parent = parent
        self.members = members
    }
}

extension Sequence {

    init() {
    }
}

extension Set {

    init() {
    }
}

extension SourceLocation {

    init(line: UInt,column: UInt,file: String) {
        self.line = line
        self.column = column
        self.file = file
    }
}

extension String {

    init() {
    }
}

extension Token {

    init(kind: Kind,location: SourceRange) {
        self.kind = kind
        self.location = location
    }
}

extension Type {

    init(entity: Entity?,width: Int?,flags: Flag,value: TypeValue) {
        self.entity = entity
        self.width = width
        self.flags = flags
        self.value = value
    }
}

extension Type.Builtin {

    init(canonicalRepresentation: IRType) {
        self.canonicalRepresentation = canonicalRepresentation
    }
}

extension Type.Flag {

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

extension Type.Function {

    init(node: AstNode,params: [Entity],returnType: Type,needsSpecialization: Bool) {
        self.node = node
        self.params = params
        self.returnType = returnType
        self.needsSpecialization = needsSpecialization
    }
}

extension Type.Metatype {

    init(instanceType: Type) {
        self.instanceType = instanceType
    }
}

extension Type.Pointer {

    init(pointeeType: Type) {
        self.pointeeType = pointeeType
    }
}

