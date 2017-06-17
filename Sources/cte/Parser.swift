
struct Parser {

    var lexer: Lexer

    var state: State

    struct State: OptionSet {
        let rawValue: UInt8

        static let parseList = State(rawValue: 0b0000_0001)
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

        switch token.kind {
        case .colon:
            return 10

        case .lparen:
            return 80

        default:
            return 0
        }
    }

    mutating func nud(for token: Token) -> AstNode {

        if let prefixOperator = PrefixOperator.lookup(token.kind) {
            return prefixOperator.nud(&self)
        }

        switch token.kind {
        case .lparen:

            let lparen = advance()

            if let nextToken = lexer.peek(), case .rparen = nextToken.kind {
                let rparen = advance()

                return AstNode(ExprParen(expr: AstNode.empty), tokens: [lparen, rparen])
            }

            var expr = expression()

            if case .comma? = lexer.peek()?.kind {
                expr = parseList(with: expr)
            }

            let rparen = advance(expecting: .lparen)
            return AstNode(ExprParen(expr: expr), tokens: [lparen, rparen])

        case .ident(let symbol):
            advance()

            let identifier = Identifier(name: symbol)
            return AstNode(identifier, tokens: [token])

        case .string(let string):
            advance()

            let litString = StringLiteral(value: string)
            return AstNode(litString, tokens: [token])

        case .number(let number):
            advance()

            let litNumber = NumberLiteral(value: number)
            return AstNode(litNumber, tokens: [token])

        case .dollar:
            let dollar = advance()

            let expr = expression()

            let ct = CompileTime(stmt: expr)
            return AstNode(ct, tokens: [dollar])

        case .lbrace:
            let lbrace = advance()

            var stmts: [AstNode] = []
            while let nextToken = lexer.peek(), nextToken.kind != .rbrace {
                let stmt = expression()
                stmts.append(stmt)
            }

            let rbrace = advance(expecting: .rbrace)

            let stmtBlock = StmtBlock(stmts: stmts)
            return AstNode(stmtBlock, tokens: [lbrace, rbrace])

        case .keywordIf:
            let ifToken = advance()

            let cond = expression()

            let body = expression()

            guard let elseToken = lexer.peek(), case .keywordElse = elseToken.kind else {
                let stmtIf = StmtIf(condition: cond, thenStmt: body, elseStmt: nil)
                return AstNode(stmtIf, tokens: [ifToken])
            }

            advance()
            let elseStmt = expression()

            let stmtIf = StmtIf(condition: cond, thenStmt: body, elseStmt: elseStmt)
            return AstNode(stmtIf, tokens: [ifToken, elseToken])

        case .keywordFn:
            let fnToken = advance()

            let lparen = advance(expecting: .lparen)

            var parameters: [AstNode] = []
            if let nextToken = lexer.peek(), nextToken.kind != .rparen {
                while true {
                    guard let parameterName = lexer.peek(), case .ident(let symbol) = parameterName.kind else {
                        reportError("Expected parameter name", at: lexer.location)
                        return AstNode.invalid
                    }
                    advance()

                    let colon = advance(expecting: .colon)

                    let typeExpr = expression()

                    let parameterNameNode = AstNode(Identifier(name: symbol), tokens: [parameterName])
                    let declaration = Declaration(identifier: parameterNameNode, type: typeExpr, value: AstNode.empty)
                    let param = AstNode(declaration, tokens: [parameterName, colon])

                    parameters.append(param)

                    if lexer.peek()?.kind != .comma {
                        break
                    }
                    advance(expecting: .comma)
                }
            }

            let rparen = advance(expecting: .rparen)

            let returnArrow = advance(expecting: .returnArrow)

            let returnType = expression()

            let body = expression()

            if body.kind != .stmtBlock {
                reportError("Body of a function should be a block statement", at: body)
            }

            let function = Function(parameters: parameters, returnType: returnType, body: body)

            return AstNode(function, tokens: [fnToken, lparen, rparen, returnArrow])

        case .keywordReturn:
            let returnToken = advance()

            let expr = expression()

            let stmtReturn = StmtReturn(value: expr)

            return AstNode(stmtReturn, tokens: [returnToken])

        default:
            fatalError()
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

            let exprCall = ExprCall(callee: lvalue, arguments: arguments)
            return AstNode(exprCall, tokens: [lparen, rparen])

        case .colon:
            let colon = advance()

            var type: AstNode?
            if lexer.peek()?.kind != .equals {
                type = expression()
            }
            let equals = advance(expecting: .equals)
            let value = expression()

            let decl = Declaration(identifier: lvalue, type: type, value: value)
            return AstNode(decl, tokens: [colon, equals])

        default:
            fatalError()
        }
    }

    /// Will parse from `,`
    mutating func parseList(with first: AstNode) -> AstNode {
        assert(lexer.peek()?.kind == .comma)

        let prevState = state
        state.insert(.parseList)
        defer {
            state = prevState
        }

        var tokens: [Token] = [advance()]

        var wasComma = false
        var exprs: [AstNode] = [first]
        loop: while true {

            guard let nextToken = lexer.peek() else {
                if wasComma {
                    reportError("Unexpected Comma", at: lexer.lastLocation)
                }
                break loop
            }

            switch nextToken.kind {
            case .rparen:

                if wasComma {
                    reportError("Unexpected comma", at: lexer.lastLocation)
                }
                break loop

            case .comma:
                if wasComma || exprs.isEmpty {
                    reportError("Unexpected comma", at: nextToken.location)
                }
                let comma = advance()
                wasComma = true
                tokens.append(comma)

            default:
                let expr = expression()
                exprs.append(expr)
                wasComma = false
            }
        }

        return AstNode(List(exprs: exprs), tokens: tokens)
    }


    @discardableResult
    mutating func advance(expecting expected: Token.Kind? = nil) -> Token {

        if let expected = expected, let token = lexer.peek(), token.kind != expected {
            reportError("Expected '" + expected.description + "'", at: token.location)
            return Token(kind: .invalid(""), location: token.location)
        }

        return lexer.pop()
    }
}
