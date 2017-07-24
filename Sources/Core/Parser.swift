
import enum LLVM.CallingConvention

struct Parser {

    var file: SourceFile

    var lexer: Lexer

    var context: Context

    init(file: SourceFile) {
        self.file = file
        self.lexer = file.lexer
        self.context = Context(state: .default, previous: nil)
    }

    class Context {
        let state: State
        var previous: Context?

        init(state: State, previous: Context?) {
            self.state = state
            self.previous = previous
        }
    }

    struct State: OptionSet {
        let rawValue: UInt16

        static let permitExprList       = State(rawValue: 0b0000_0001)
        static let permitAssignOrDecl   = State(rawValue: 0b0000_0010)
        static let permitCase           = State(rawValue: 0b0000_0100)
        static let permitCompositeLit   = State(rawValue: 0b0000_1000)

        static let functionBody         = State(rawValue: 0b0001_0000)
        static let structBody           = State(rawValue: 0b0010_0000)
        static let unionBody            = State(rawValue: 0b0100_0000)
        static let foreign              = State(rawValue: 0b1000_0000)
        static let leaveTerminators     = State(rawValue: 0b0000_0001 << 8)

        static let `default`            = [.permitExprList, .permitAssignOrDecl] as State
    }

    enum StateChange {
        case parseType
        case parseReturnType
        case parseSingle
        case parseDeclValue
        case parseFunctionBody
        case parseStructBody
        case parseUnionBody
        case parseSwitchBody
        case parseDeferExpr
        case parseForeignDirectiveBody
        case parseCallingConventionDirectiveBody
        case parseParamIdentifiers
        case parseCompositeLitElements
        case parseForStmts
        case parseBlock
    }

    mutating func pushContext(changingStateTo stateChange: StateChange, willEnsureTerminated: Bool = false) {

        var state = context.state

        switch stateChange {
        case .parseType:
            state = []
        case .parseReturnType:
            state = [.permitExprList]
        case .parseSingle:
            state = []
        case .parseDeclValue:
            state = [.permitExprList, .permitCompositeLit]
        case .parseFunctionBody:
            state = .default
            state.insert(.functionBody)
        case .parseStructBody:
            state = [.permitExprList, .permitAssignOrDecl, .structBody]
        case .parseUnionBody:
            state = [.permitAssignOrDecl, .unionBody]
        case .parseSwitchBody:
            state.insert(.permitCase)
        case .parseDeferExpr:
            state = []
        case .parseForeignDirectiveBody:
            state = [.permitAssignOrDecl, .foreign]
        case .parseCallingConventionDirectiveBody:
            state = [.permitAssignOrDecl, .foreign]
        case .parseParamIdentifiers:
            state = [.permitExprList]
        case .parseCompositeLitElements:
            state = [.permitCompositeLit]
        case .parseForStmts:
            state = [.permitExprList, .permitAssignOrDecl, .leaveTerminators]
        case .parseBlock:
            state = state.subtracting(.leaveTerminators)
        }

        if willEnsureTerminated {
            state.insert(.leaveTerminators)
        }

        let newContext = Context(state: state, previous: context)
        context = newContext
    }

    mutating func popContext() {
        context = context.previous!
    }

    mutating func parse() -> [AstNode] {

        consumeNewlines()

        var nodes: [AstNode] = []
        while lexer.peek() != nil {

            let node = expression()
            nodes.append(node)

            consumeTerminatorIfExprUsedAsStmt(node)
        }

        return nodes
    }

    mutating func expression(_ rbp: UInt8 = 0) -> AstNode {

        guard let token = lexer.peek() else {
            return AstNode.empty
        }

        var left = nud(for: token)

        while let nextToken = lexer.peek(), let lbp = lbp(for: nextToken),
            rbp < lbp
        {

            left = led(for: nextToken, with: left)
        }

        return left
    }

    mutating func lbp(for token: Token) -> UInt8? {

        if let lbp = InfixOperator.lookup(token.kind)?.lbp {
            return lbp
        }

        let lbp = token.kind.lbp
        if !context.state.contains(.permitExprList), token.kind == .comma {
            return 0
        }
        if !context.state.contains(.permitAssignOrDecl), token.kind == .colon || token.kind == .equals {
            return 0
        }
        if !context.state.contains(.permitCompositeLit), token.kind == .lbrace {
            return 0
        }

        return lbp
    }

    mutating func nud(for token: Token) -> AstNode {

        if let prefixOperator = PrefixOperator.lookup(token.kind) {
            return prefixOperator.nud(&self)
        }

        switch token.kind {
        case .lparen:

            let lparen = advance()

            if lexer.peek()?.kind == .rparen {
                let rparen = advance()

                return AstNode(AstNode.Paren(expr: AstNode.empty), tokens: [lparen, rparen])
            }

            let expr = expression()

            let rparen = advance(expecting: .rparen)
            return AstNode(AstNode.Paren(expr: expr), tokens: [lparen, rparen])

        case .comment:
            advance()

            consumeNewlines()

            let comment = AstNode.Comment(comment: token.stringValue)
            return AstNode(comment, tokens: [token])

        case .ident:
            advance()

            let identifier = AstNode.Identifier(name: token.stringValue)
            return AstNode(identifier, tokens: [token])

        case .string:
            advance()

            let litString = AstNode.StringLiteral(value: token.stringValue)
            return AstNode(litString, tokens: [token])

        case .float:
            advance()

            let floatLit = AstNode.FloatLiteral(value: token.floatingValue)
            return AstNode(floatLit, tokens: [token])

        case .integer:
            advance()

            let integerLit = AstNode.IntegerLiteral(value: token.integerValue)
            return AstNode(integerLit, tokens: [token])

        case .lbrace:
            pushContext(changingStateTo: .parseBlock)
            let lbrace = advance()
            consumeNewlines()

            var stmts: [AstNode] = []
            while lexer.peek()?.kind != .rbrace {
                let stmt = expression()
                stmts.append(stmt)

                if stmts.last!.kind == .return {
                    break
                }

                consumeTerminatorIfExprUsedAsStmt(stmt)
            }

            let rbrace = advance(expecting: .rbrace)
            popContext()

            var flags: BlockFlag = []
            if context.state.contains(.functionBody) {
                flags.insert(.function)
            }
            // these flags indicate that the caller will cleanup terminators
            if context.state.intersection([.functionBody, .structBody, .unionBody, .foreign]).isEmpty &&
                !context.state.contains(.leaveTerminators) {
                expectTerminator()
            }

            let value = AstNode.Block(stmts: stmts, flags: flags)
            return AstNode(value, tokens: [lbrace, rbrace])

        case .ellipsis:
            let ellispsis = advance()

            pushContext(changingStateTo: .parseType)
            let type = expression()
            popContext()

            let variadic = AstNode.Variadic(type: type, cCompatible: false)
            return AstNode(variadic, tokens: [ellispsis])

        case .dollar:
            let dollar = advance()

            pushContext(changingStateTo: .parseSingle)
            let stmt = expression()
            popContext()

            if stmt.kind == .declaration {
                stmt.tokens.insert(dollar, at: 0)
                stmt.asDeclaration.flags.insert(.compileTime)
                return stmt
            }

            let ct = AstNode.CompileTime(stmt: stmt)
            return AstNode(ct, tokens: [dollar])

        case .keywordIf:
            let ifToken = advance()

            let cond = expression()

            let body = expression()

            guard lexer.peek()?.kind == .keywordElse else {
                if !body.isStmt {
                    expectTerminator()
                }
                let stmtIf = AstNode.If(condition: cond, thenStmt: body, elseStmt: nil)
                return AstNode(stmtIf, tokens: [ifToken])
            }

            let elseToken = advance()
            let elseStmt = expression()
            if !elseStmt.isStmt {
                expectTerminator()
            }

            let value = AstNode.If(condition: cond, thenStmt: body, elseStmt: elseStmt)
            return AstNode(value, tokens: [ifToken, elseToken])

        case .keywordFor:
            let forToken = advance()

            var tokens: [Token] = [forToken]
            var exprs: [AstNode] =  []
            pushContext(changingStateTo: .parseForStmts)
            while let token = lexer.peek(), token.kind != .lbrace {

                if token.kind == .semicolon {
                    exprs.append(.empty)
                } else {
                    let expr = expression()
                    exprs.append(expr)
                }

                if lexer.peek()?.kind != .lbrace {
                    let semicolon = advance(expecting: .semicolon)
                    tokens.append(semicolon)

                    if lexer.peek()?.kind == .lbrace {
                        exprs.append(.empty)
                        break
                    }
                }
            }
            popContext()

            let body = expression()

            expectTerminator()

            var initializer: AstNode?
            var condition: AstNode?
            var step: AstNode?

            switch exprs.count {
            case 0:
                break
            case 1:
                condition = exprs[0]
            case 3:
                initializer = exprs[0]
                condition = exprs[1]
                step = exprs[2]
            default:
                reportError("`for` statements require 0, 1 or 3 statements", at: forToken)
                return AstNode.invalid(with: [forToken])
            }

            let fór = AstNode.For(label: nil, initializer: initializer, condition: condition, step: step, body: body)
            return AstNode(fór, tokens: tokens)

        case .keywordFn:
            let fnToken = advance()

            let lparen = advance(expecting: .lparen)
            consumeNewlines()

            var params: [AstNode] = []
            if lexer.peek()?.kind != .rparen {

                while lexer.peek()?.kind != .rparen {
                    pushContext(changingStateTo: .parseParamIdentifiers)
                    let identifiers = expression()
                    popContext()
                    if lexer.peek()?.kind != .colon {
                        params.append(identifiers) // handles function signatures `fn (i8, i8, i8, i8) -> i32`
                        if lexer.peek()?.kind != .comma {
                            break
                        }
                        advance()
                        consumeNewlines()
                        continue
                    }
                    let colon = advance()
                    pushContext(changingStateTo: .parseType)
                    let type = expression()
                    popContext()

                    let sameTypeParams = explode(identifiers)
                        .map({ AstNode.Parameter(name: $0, type: type) })
                        .map({ AstNode($0, tokens: [colon]) })

                    params.append(contentsOf: sameTypeParams)

                    if lexer.peek()?.kind != .comma {
                        break
                    }
                    advance()
                }
            }

            let rparen = advance(expecting: .rparen)
            let returnArrow = advance(expecting: .returnArrow)

            pushContext(changingStateTo: .parseReturnType)
            let returnTypeList = expression()
            popContext()

            let returnTypes = explode(returnTypeList)

            if lexer.peek()?.kind != .lbrace {
                let value = AstNode.FunctionType(parameters: params, returnTypes: returnTypes, flags: [])
                return AstNode(value, tokens: [fnToken, lparen, rparen, returnArrow])
            }

            for param in params
                where param.kind != .parameter
            {
                assert(param.kind == .identifier)
                reportError("Expected named parameter", at: param)
                attachNote("Function literals require all arguments be named")
                attachNote("If don't use a parameter but need it in the function signature use '_: \(param)'")
            }

            pushContext(changingStateTo: .parseFunctionBody)
            let body = expression()
            popContext()

            if body.kind != .block {
                reportError("Body of a function should be a block statement", at: body)
            }

            let value = AstNode.Function(parameters: params, returnTypes: returnTypes, body: body, flags: [])
            return AstNode(value, tokens: [fnToken, lparen, rparen, returnArrow])

        case .keywordSwitch:
            let switchToken = advance()

            let subject: AstNode?
            switch lexer.peek()?.kind {
            case .lbrace?:
                subject = nil

            default:
                subject = expression()
            }

            let lbrace = advance(expecting: .lbrace)

            pushContext(changingStateTo: .parseSwitchBody)
            var cases: [AstNode] = []
            while lexer.peek()?.kind != .rbrace {
                let expr = expression()
                cases.append(expr)

                expectTerminator()
            }
            popContext()

            let rbrace = advance(expecting: .rbrace)

            expectTerminator()

            let świtch = AstNode.Switch(label: nil, subject: subject, cases: cases)
            return AstNode(świtch, tokens: [switchToken, lbrace, rbrace])

        case .keywordCase:
            let startToken = advance()
            let isDefault = lexer.peek()?.kind == .colon

            guard context.state.contains(.permitCase) else {
                reportError("Unexpected case outside of switch", at: startToken)
                if lexer.peek()?.kind == .colon { advance() }
                return AstNode.invalid
            }

            var match: AstNode?
            if !isDefault {
                match = expression(Token.Kind.colon.lbp)
            }

            let colon = advance(expecting: .colon)
            consumeNewlines()

            var stmts: [AstNode] = []
            if lexer.peek()?.kind == .keywordCase {
                stmts.append(.invalid)

                if isDefault {
                    reportError("`default` label in a `switch` must have exactly one executable statement or `break`", at: lexer)
                } else {
                    reportError("`case` label in a `switch` must have exactly one executable statement, `fallthrough` or `break`", at: lexer)
                }
            } else {
                while let token = lexer.peek()?.kind, token != .keywordCase && token != .rbrace {
                    let expr = expression()
                    stmts.append(expr)
                    expectTerminator()
                }
            }

            let value = AstNode.Block(stmts: stmts, flags: [])
            let block = AstNode(value, tokens: [colon])
            let ćase = AstNode.Case(condition: match, block: block)
            return AstNode(ćase, tokens: [startToken, colon])

        case .keywordReturn:
            let ŕeturn = advance()

            // FIXME(vdka): This currently requires return values to be on the same line as the return keyword
            let terminators: [Token.Kind] = [.rparen, .rbrace, .keywordElse, .keywordCase, .newline]

            var exprs: [AstNode] = []
            if let tokenKind = lexer.peek()?.kind, !terminators.contains(tokenKind) {
                let exprList = expression()
                exprs = explode(exprList)
            }

            if exprs.count < 2 {
                // NOTE: expression lists consume newlines
                expectTerminator()
            }

            let value = AstNode.Return(values: exprs)
            return AstNode(value, tokens: [ŕeturn])

        case .keywordBreak:
            let bŕeak = advance()

            let nextToken = lexer.peek()
            var label: AstNode?
            switch nextToken?.kind {
            case .newline?:
                break

            case .ident?:
                label = expression()

            default:
                reportError("'break' must be followed by a newline or a label to break to", at: bŕeak)
            }

            let value = AstNode.Break(label: label)
            return AstNode(value, tokens: [bŕeak])

        case .keywordContinue:
            let ćontinue = advance()

            let nextToken = lexer.peek()
            var label: AstNode?
            switch nextToken?.kind {
            case .newline?:
                break

            case .ident?:
                label = expression()

            default:
                reportError("'continue' must be followed by a newline or a label to continue to", at: ćontinue)
            }

            let value = AstNode.Continue(label: label)
            return AstNode(value, tokens: [ćontinue])

        case .keywordFallthrough:
            let fállthrough = advance()

            advance(expecting: .newline, errorMessage: "'fallthrough' must be followed by a newline")

            let value = AstNode.Fallthrough()
            return AstNode(value, tokens: [fállthrough])

        case .keywordStruct:
            let strućt = advance()

            guard lexer.peek()?.kind == .lbrace else {
                reportError("Expected '{' to follow 'struct'", at: strućt)
                return AstNode.invalid
            }

            pushContext(changingStateTo: .parseStructBody)
            let body = expression()
            popContext()

            let value = AstNode.StructType(declarations: body.asBlock.stmts)
            return AstNode(value, tokens: [strućt] + body.tokens)

        case .keywordUnion:
            let union = advance()

            guard lexer.peek()?.kind == .lbrace else {
                reportError("Expected '{' to follow 'union'", at: union)
                return AstNode.invalid
            }

            pushContext(changingStateTo: .parseUnionBody)
            let body = expression()
            popContext()

            let value = AstNode.UnionType(declarations: body.asBlock.stmts)
            return AstNode(value, tokens: [union] + body.tokens)

        case .directiveImport:
            let directive = advance()

            // 3 possibilities:
            // <string> <newline>
            // <string> <identifier> <newline>
            // <string> <dot> <newline>

            let pathToken = advance(expecting: .string)
            let symbolToken = lexer.peek()

            var symbol: AstNode?
            switch symbolToken?.kind {
            case .ident?:
                symbol = expression()

            case .dot?:
                advance()

            case .newline?, nil:
                symbol = nil

            default:
                reportError("Expected identifier to bind imported entities to or '.' to import them into the current scope", at: symbolToken!)
                expectTerminator()
                return AstNode.invalid(with: [directive, pathToken])
            }

            guard let importedFile = SourceFile.new(path: pathToken.stringValue, importedFrom: file) else {
                reportError("Failed to open '\(pathToken.stringValue)' for reading", at: pathToken)
                expectTerminator()
                return AstNode.invalid(with: [directive, pathToken])
            }

            var tokens = [directive, pathToken]
            if let symbolToken = symbolToken {
                tokens.append(symbolToken)
            }

            expectTerminator()

            let value = AstNode.Import(path: pathToken.stringValue, symbol: symbol, includeSymbolsInParentScope: symbolToken?.kind == .dot, file: importedFile)
            let node = AstNode(value, tokens: tokens)
            file.importStatements.append(node)

            return node

        case .directiveLibrary:
            let directive = advance()

            let pathToken = advance(expecting: .string)

            var symbol: AstNode?
            if lexer.peek()?.kind == .ident {
                symbol = expression()
            }

            expectTerminator()

            let value = AstNode.Library(path: pathToken.stringValue, symbol: symbol)
            return AstNode(value, tokens: [directive, pathToken])

        case .directiveForeign:
            let directive = advance()
            let library = expression()

            guard library.kind == .identifier else {
                reportError("Expected identifier for library", at: library)
                return AstNode.invalid
            }

            pushContext(changingStateTo: .parseForeignDirectiveBody, willEnsureTerminated: true)
            let stmt = expression()
            popContext()

            expectTerminator()

            if stmt.kind == .declaration {
                stmt.asDeclaration.flags.insert(.foreign)
                if !stmt.asDeclaration.isSpecificCallingConvention {
                    stmt.asDeclaration.flags.callingConvention = .c
                }
            } else if stmt.kind == .block {
                stmt.asBlock.flags.insert(.foreign)
                if !stmt.asBlock.isSpecificCallingConvention {
                    stmt.asBlock.flags.callingConvention = .c
                }
            } else {
                reportError("Expected a declaration or block of declarations", at: stmt)
            }

            stmt.tokens.insert(directive, at: 0)

            return stmt

        case .directiveCallingConvention:
            let directive = advance()
            consumeNewlines()

            pushContext(changingStateTo: .parseCallingConventionDirectiveBody, willEnsureTerminated: true)
            let convention = expression()
            popContext()

            guard convention.kind == .litString else {
                reportError("Expected string for calling convention", at: convention)
                let valid = ["c", "fast", "cold", "webKitJS", "anyReg", "x86Stdcall", "x86Fastcall"]
                attachNote("NOTE: Valid calling conventions are:\n" + valid.map({ "    " + $0 }).joined(separator: "\t"))
                return AstNode.invalid
            }

            var callingConvention: CallingConvention
            switch convention.asStringLiteral.value {
            case "c":
                callingConvention = .c
            case "fast":
                callingConvention = .fast
            case "cold":
                callingConvention = .cold
            case "webKitJS":
                callingConvention = .webKitJS
            case "anyReg":
                callingConvention = .anyReg
            case "x86Stdcall":
                callingConvention = .x86Stdcall
            case "x86Fastcall":
                callingConvention = .x86Fastcall
            default:
                reportError("Unrecognized calling convention \(convention)", at: convention)
                let valid = ["c", "fast", "cold", "webKitJS", "anyReg", "x86Stdcall", "x86Fastcall"]
                attachNote("NOTE: Valid calling conventions are:\n" + valid.map({ "    " + $0 }).joined(separator: "\t"))

                callingConvention = .c
            }

            pushContext(changingStateTo: .parseForeignDirectiveBody)
            let stmt = expression()
            popContext()

            expectTerminator()

            if stmt.kind == .declaration {
                stmt.asDeclaration.flags.callingConvention = callingConvention
            } else if stmt.kind == .block {
                stmt.asBlock.flags.callingConvention = callingConvention
            } else {
                reportError("Expected a declaration or block of declarations", at: stmt)
            }

            stmt.tokens.insert(directive, at: 0)

            return stmt

        case .directiveDiscardable:
            let directive = advance()
            consumeNewlines()
            let stmt = expression()

            stmt.tokens.insert(directive, at: 0)

            let isDeclaration = stmt.kind == .declaration
            let decl = stmt.asDeclaration
            let isFunction = decl.isFunction
            let isForeignFunction = context.state.contains(.foreign) && decl.isFunctionType

            guard isDeclaration && (isFunction || isForeignFunction) else {
                reportError("#discardable is only valid only function declarations", at: stmt)
                return stmt
            }

            if isFunction {
                decl.values[0].asFunction.flags.insert(.discardableResult)
            } else {
                decl.values[0].asFunctionType.flags.insert(.discardableResult)
            }

            return stmt

        case .directiveCvargs:
            let directive = advance()
            let stmt = expression()

            guard stmt.kind == .variadic else {
                reportError("#cvargs is only valid on variadics", at: directive)
                return stmt
            }

            stmt.asVariadic.cCompatible = true

            return stmt

        default:
            fatalError("Parser has no nud for \(token)")
        }
    }

    mutating func led(for token: Token, with lvalue: AstNode) -> AstNode {

        if let infixOperator = InfixOperator.lookup(token.kind) {
            return infixOperator.led(&self, lvalue)
        }

        switch token.kind {
        case .lparen:
            let lparen = advance()

            var arguments: [AstNode] = []
            if lexer.peek()?.kind != .rparen {
                let argumentList = expression()
                arguments = explode(argumentList)
            }

            let rparen = advance(expecting: .rparen)

            let exprCall = AstNode.Call(callee: lvalue, arguments: arguments)
            return AstNode(exprCall, tokens: [lparen, rparen])

        case .lbrace:
            let lbrace = advance()
            consumeNewlines()

            var fields: [AstNode.CompositeLiteralField] = []
            if lexer.peek()?.kind != .rbrace {

                var named: Int = 0
                while lexer.peek()?.kind != .rbrace {
                    pushContext(changingStateTo: .parseCompositeLitElements)
                    let nameOrValue = expression()
                    popContext()
                    if lexer.peek()?.kind != .colon {
                        let value = AstNode.CompositeLiteralField(identifier: nil, value: nameOrValue)
                        fields.append(value) // handles function signatures `fn (i8, i8, i8, i8) -> i32`
                        if lexer.peek()?.kind != .comma {
                            break
                        }
                        advance()
                        consumeNewlines()
                        continue
                    }
                    advance()

                    guard nameOrValue.kind == .identifier else {
                        reportError("Invalid field name '\(nameOrValue)'", at: nameOrValue)
                        continue
                    }

                    named += 1

                    pushContext(changingStateTo: .parseCompositeLitElements)
                    let value = expression()
                    popContext()

                    let field = AstNode.CompositeLiteralField(identifier: nameOrValue, value: value)

                    fields.append(field)

                    if lexer.peek()?.kind != .comma {
                        break
                    }
                    advance()
                    consumeNewlines()
                }

                if named != 0 && named < fields.count {
                    reportError("Mixture of named and unnamed fields in struct initializer", at: lbrace)
                }
            }

            let rbrace = advance(expecting: .rbrace)

            let exprs = fields.map({ AstNode($0, tokens: [] )})
            let value = AstNode.CompositeLiteral(typeNode: lvalue, elements: exprs)
            return AstNode(value, tokens: [lbrace, rbrace])

        case .dot:
            let dot = advance()
            let memberToken = advance(expecting: .ident)

            let identifier = AstNode.Identifier(name: memberToken.stringValue)

            let member = AstNode(identifier, tokens: [memberToken])

            let memberAccess = AstNode.Access(aggregate: lvalue, member: member)
            return AstNode(memberAccess, tokens: [dot])

        case .comma:
            let comma = advance()
            let expr = expression(comma.kind.lbp)
            let list = append(lvalue, expr)
            consumeNewlines()
            list.tokens.append(comma)
            return list

        case .equals:
            let equals = advance()

            let rvalue = expression(Token.Kind.equals.lbp)
            let values = explode(rvalue)

            if values.count < 2 {
                // NOTE: expression lists consume newlines
                expectTerminator()
            }

            let assign = AstNode.Assign(lvalues: explode(lvalue), rvalues: values)
            return AstNode(value: assign, tokens: [equals])

        case .colon:
            let colon = advance()

            var type: AstNode?
            switch lexer.peek()?.kind {
            case .equals?, .colon?:
                break

            case .keywordFor?:
                let stmt = expression()
                stmt.asUncheckedFor.label = lvalue
                return stmt

            case .keywordSwitch?:
                let stmt = expression()
                stmt.asUncheckedSwitch.label = lvalue
                return stmt

            default:
                assert(colon.kind.lbp == Token.Kind.equals.lbp)

                pushContext(changingStateTo: .parseType)
                type = expression(colon.kind.lbp)
                popContext()
            }

            guard let nextToken = lexer.peek(), nextToken.kind == .equals || nextToken.kind == .colon else {
                assert(type != nil) // matches `x: foo`

                expectTerminator()

                let decl = AstNode.Declaration(names: explode(lvalue), type: type, values: [], linkName: nil, flags: [])
                return AstNode(decl, tokens: [colon])
            }

            let token = advance()

            pushContext(changingStateTo: .parseDeclValue)
            let value = expression(colon.kind.lbp)
            popContext()

            let values = explode(value)

            if values.count > 1 {
                assert(value.kind == .list)

                let firstUnpermittedInList = values.enumerated()
                    .first(where: { _, node in
                        return node.kind == .function || (node.kind == .functionType && context.state.contains(.foreign))
                    })

                if let firstUnpermittedInList = firstUnpermittedInList {
                    let comma = value.tokens[firstUnpermittedInList.offset]
                    reportError("Unexpected comma", at: comma)
                    attachNote("Multiple values with function literals are forbidden for reasons of code hygiene")
                    attachNote("You should break this into multiple, separate declarations")
                }
            }

            if values.count < 2 {
                // NOTE: expression lists consume newlines
                expectTerminator()
            }

            let flags = token.kind == .colon ? DeclarationFlags.compileTime : []
            let decl = AstNode.Declaration(names: explode(lvalue), type: type, values: values, linkName: nil, flags: flags)
            return AstNode(decl, tokens: [colon, token])

        case .directiveLinkname:
            let directive = advance()
            let name = advance(expecting: .string)
            guard lvalue.kind == .declaration else {
                reportError("Linkname is only valid on declarations", at: directive)
                return AstNode.invalid(with: [directive, name])
            }

            guard lvalue.asDeclaration.linkName == nil else {
                reportError("Multiple linkname directives for single declaration", at: directive)
                return lvalue
            }

            lvalue.asDeclaration.linkName = name.stringValue

            return lvalue

        default:
            fatalError()
        }
    }

    mutating func consumeTerminator() {
        guard !context.state.contains(.leaveTerminators) else {
            return
        }
        if lexer.peek()?.kind == .semicolon {
            advance()
        }

        while let token = lexer.peek()?.kind, token == .newline {
            advance()
        }
    }

    mutating func consumeTerminatorIfExprUsedAsStmt(_ node: AstNode) {
        guard !context.state.contains(.leaveTerminators) else {
            return
        }
        // NOTE: Currently only calls can be either an expression or statement
        if node.kind == .call {
            consumeTerminator()
        }
    }

    mutating func expectTerminator(line: UInt = #line) {
        guard !context.state.contains(.leaveTerminators) else {
            return
        }
        let token = lexer.peek()
        if token?.kind != .newline && token?.kind != .semicolon {
            reportError("Expected either a ';' or a newline as terminator", at: token ?? Token(kind: .invalid, value: nil, location: lexer.location ..< lexer.location), line: line)
        }
        consumeTerminator()
    }

    mutating func consumeNewlines() {
        guard !context.state.contains(.leaveTerminators) else {
            return
        }

        while let token = lexer.peek()?.kind, token == .newline {
            advance()
        }
    }

    @discardableResult
    mutating func advance(expecting expected: Token.Kind? = nil, errorMessage: String? = nil) -> Token {

        if let expected = expected, let token = lexer.peek(), token.kind != expected {
            if let errorMessage = errorMessage {
                reportError(errorMessage, at: token)
            } else {
                reportError("Expected '" + expected.description + "'", at: token)
            }
            return Token(kind: .invalid, value: nil, location: token.location)
        }

        return lexer.pop()
    }

    func append(_ l: AstNode, _ r: AstNode) -> AstNode {
        switch (l.kind, r.kind) {
        case (.list, .list):
            let list = AstNode.List(values: l.asList.values + r.asList.values)
            return AstNode(list, tokens: l.tokens + r.tokens)

        case (_, .list):
            let list = AstNode.List(values: [l] + r.asList.values)
            return AstNode(list, tokens: l.tokens + r.tokens)

        case (.list, _):
            let list = AstNode.List(values: l.asList.values + [r])
            return AstNode(list, tokens: l.tokens + r.tokens)

        default:
            let list = AstNode.List(values: [l, r])
            return AstNode(list, tokens: l.tokens + r.tokens)
        }
    }

    func explode(_ node: AstNode) -> [AstNode] {
        switch node.kind {
        case .empty:
            return []

        case .list:
            return node.asList.values

        default:
            return [node]
        }
    }

}

extension Token.Kind {

    var lbp: UInt8 {
        switch self {
        case .colon, .equals:
            return 10
            
        case .directiveLinkname:
            return 10

        case .comma:
            return 15

        case .lparen, .dot:
            return 80

        case .lbrace:
            return 150

        default:
            return 0
        }
    }
}
