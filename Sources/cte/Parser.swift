
struct Parser {

    var lexer: Lexer

    var state: State

    struct State: OptionSet {
        let rawValue: UInt8

        static let parseList            = State(rawValue: 0b0000_0001)
        static let isDeclarationValue   = State(rawValue: 0b0000_0010)
    }

    mutating func parse() -> [AstNode] {

        var nodes: [AstNode] = []
        while lexer.peek() != nil {

            let node = expression()

            nodes.append(node)
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

        if let infixOperator = InfixOperator.lookup(token.kind) {
            return infixOperator.lbp
        }

        return token.kind.lbp
    }

    mutating func nud(for token: Token) -> AstNode {
        defer {
            consumeNewlines()
        }

        if let prefixOperator = PrefixOperator.lookup(token.kind) {
            return prefixOperator.nud(&self)
        }

        switch token.kind {
        case .lparen:

            let lparen = advance()

            if let nextToken = lexer.peek(), case .rparen = nextToken.kind {
                let rparen = advance()

                return AstNode(AstNode.Paren(expr: AstNode.empty), tokens: [lparen, rparen])
            }

            let expr = expression()

            let rparen = advance(expecting: .rparen)
            return AstNode(AstNode.Paren(expr: expr), tokens: [lparen, rparen])

        case .comment(let comment):
            advance()

            let comment = AstNode.Comment(comment: comment)
            return AstNode.init(comment, tokens: [token])

        case .ident(let symbol):
            advance()

            let identifier = AstNode.Identifier(name: symbol)
            return AstNode(identifier, tokens: [token])

        case .string(let string):
            advance()

            let litString = AstNode.StringLiteral(value: string)
            return AstNode(litString, tokens: [token])

        case .float(let val):
            advance()

            let floatLit = AstNode.FloatLiteral(value: val)
            return AstNode(floatLit, tokens: [token])

        case .integer(let val):
            advance()

            let integerLit = AstNode.IntegerLiteral(value: val)
            return AstNode(integerLit, tokens: [token])

        case .lbrace:
            let lbrace = advance()

            var stmts: [AstNode] = []
            while let nextToken = lexer.peek(), nextToken.kind != .rbrace {
                let stmt = expression()
                stmts.append(stmt)
            }

            let rbrace = advance(expecting: .rbrace)

            let stmtBlock = AstNode.Block(stmts: stmts)
            return AstNode(stmtBlock, tokens: [lbrace, rbrace])

        case .dollar:
            let dollar = advance()
            let stmt = expression()

            if stmt.kind == .declaration {
                let decl = stmt.asDeclaration
                stmt.tokens.insert(dollar, at: 0)
                stmt.value = AstNode.Declaration(identifier: decl.identifier, type: decl.type, value: decl.value, isCompileTime: true)
                return stmt
            }

            let ct = AstNode.CompileTime(stmt: stmt)
            return AstNode(ct, tokens: [dollar])

        case .keywordIf:
            let ifToken = advance()

            let cond = expression()

            let body = expression()

            guard let elseToken = lexer.peek(), case .keywordElse = elseToken.kind else {
                let stmtIf = AstNode.If(condition: cond, thenStmt: body, elseStmt: nil)
                return AstNode(stmtIf, tokens: [ifToken])
            }

            advance()
            let elseStmt = expression()

            let stmtIf = AstNode.If(condition: cond, thenStmt: body, elseStmt: elseStmt)
            return AstNode(stmtIf, tokens: [ifToken, elseToken])

        case .keywordFn:
            let fnToken = advance()

            let lparen = advance(expecting: .lparen)
            consumeNewlines()

            var params: [AstNode] = []
            while true {

                let param = expression()
                if state.contains(.isDeclarationValue), param.kind != .declaration {
                    reportError("Procedure literals must provide parameter names in their function prototype", at: param)
                }

                params.append(param)
                if lexer.peek()?.kind != .comma {
                    break
                }
                advance(expecting: .comma)
                consumeNewlines()
            }

            consumeNewlines()
            let rparen = advance(expecting: .rparen)

            let returnArrow = advance(expecting: .returnArrow)

            let returnType = expression(Token.Kind.equals.lbp)

            if lexer.peek()?.kind != .lbrace {
                let functionType = AstNode.FunctionType(parameters: params, returnType: returnType)
                return AstNode(functionType, tokens: [fnToken, lparen, rparen, returnArrow])
            }

            let body = expression()

            if body.kind != .block {
                reportError("Body of a function should be a block statement", at: body)
            }

            let function = AstNode.Function(parameters: params, returnType: returnType, body: body)

            return AstNode(function, tokens: [fnToken, lparen, rparen, returnArrow])

        case .keywordReturn:
            let returnToken = advance()

            let expr = expression()

            let stmtReturn = AstNode.Return(value: expr)

            return AstNode(stmtReturn, tokens: [returnToken])

        default:
            fatalError("Parser has no nud for \(token)")
        }
    }

    mutating func led(for token: Token, with lvalue: AstNode) -> AstNode {
        defer {
            consumeNewlines()
        }

        if let infixOperator = InfixOperator.lookup(token.kind) {
            return infixOperator.led(&self, lvalue)
        }

        switch token.kind {
        case .lparen:
            let lparen = advance()

            var arguments: [AstNode] = []
            if let nextToken = lexer.peek(), nextToken.kind != .rparen {
                while true {

                    let argument = expression()
                    arguments.append(argument)

                    if lexer.peek()?.kind != .comma {
                        break
                    }
                    advance(expecting: .comma)
                }
            }

            let rparen = advance(expecting: .rparen)

            let exprCall = AstNode.Call(callee: lvalue, arguments: arguments)
            return AstNode(exprCall, tokens: [lparen, rparen])

        case .equals:
            let equals = advance()

            let value = expression(Token.Kind.equals.lbp)

            let assign = AstNode.Assign(lvalue: lvalue, rvalue: value)

            return AstNode(value: assign, tokens: [equals])

        case .colon:
            let colon = advance()

            var type: AstNode?
            switch lexer.peek()?.kind {
            case .equals?, .colon?:
                break

            default:
                type = expression(Token.Kind.equals.lbp)
            }

            guard let nextToken = lexer.peek(), nextToken.kind == .equals || nextToken.kind == .colon else {
                // matches `x: foo`
                assert(type != nil)
                let decl = AstNode.Declaration(identifier: lvalue, type: type, value: .empty, isCompileTime: false)
                return AstNode(decl, tokens: [colon])
            }

            let token = advance()

            let prevState = state
            state.insert(.isDeclarationValue)
            let value = expression(Token.Kind.equals.lbp)
            state = prevState

            let decl = AstNode.Declaration(identifier: lvalue, type: type, value: value, isCompileTime: token.kind == .colon)
            return AstNode(decl, tokens: [colon, token])

        default:
            fatalError()
        }
    }

    mutating func consumeNewlines() {
        while lexer.peek()?.kind == .newline {
            advance()
        }
    }

    @discardableResult
    mutating func advance(expecting expected: Token.Kind? = nil) -> Token {

        if let expected = expected, let token = lexer.peek(), token.kind != expected {
            reportError("Expected '" + expected.description + "'", at: token)
            return Token(kind: .invalid(""), location: token.location)
        }

        return lexer.pop()
    }
}

extension Token.Kind {

    var lbp: UInt8 {
        switch self {
        case .colon, .equals:
            return 10

        case .lparen:
            return 80

        default:
            return 0
        }
    }
}
