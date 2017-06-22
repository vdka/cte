
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

            let rparen = advance(expecting: .lparen)
            return AstNode(AstNode.Paren(expr: expr), tokens: [lparen, rparen])

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

            var parameters: [AstNode] = []
            if let nextToken = lexer.peek(), nextToken.kind != .rparen {
                while true {

                    var dollar: Token?
                    if lexer.peek()?.kind == .dollar {
                        dollar = advance()
                    }

                    guard let parameterName = lexer.peek(), case .ident(let symbol) = parameterName.kind else {
                        reportError("Expected parameter name", at: lexer.location)
                        return AstNode.invalid
                    }
                    advance()

                    let colon = advance(expecting: .colon)

                    let typeExpr = expression()

                    let isCT = dollar != nil

                    let parameterNameNode = AstNode(AstNode.Identifier(name: symbol), tokens: isCT ? [dollar!, parameterName] : [parameterName])
                    let declaration = AstNode.Declaration(identifier: parameterNameNode, type: typeExpr, value: AstNode.empty, isCompileTime: isCT)
                    let param = AstNode(declaration, tokens: [parameterName, colon])

                    parameters.append(param)

                    if lexer.peek()?.kind != .comma {
                        break
                    }
                    advance(expecting: .comma)
                    consumeNewlines()
                }
            }

            consumeNewlines()
            let rparen = advance(expecting: .rparen)

            let returnArrow = advance(expecting: .returnArrow)

            let returnType = expression()

            let body = expression()

            if body.kind != .block {
                reportError("Body of a function should be a block statement", at: body)
            }

            let function = AstNode.Function(parameters: parameters, returnType: returnType, body: body)

            return AstNode(function, tokens: [fnToken, lparen, rparen, returnArrow])

        case .keywordReturn:
            let returnToken = advance()

            let expr = expression()

            let stmtReturn = AstNode.Return(value: expr)

            return AstNode(stmtReturn, tokens: [returnToken])

        default:
            fatalError()
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

        case .colon:
            let colon = advance()

            var type: AstNode?
            switch lexer.peek()?.kind {
            case .equals?, .colon?:
                break

            default:
                type = expression()
            }

            guard let nextToken = lexer.peek(), nextToken.kind == .equals || nextToken.kind == .colon else {
                // catches `x: foo`
                reportError("Expected '=' or ':' followed by an inital value", at: lexer.location)
                attachNote("If your aim is to create an uninitialized value, you cannot. At least for now.")
                return AstNode.invalid
            }

            let token = advance()

            let value = expression()

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
            reportError("Expected '" + expected.description + "'", at: token.location)
            return Token(kind: .invalid(""), location: token.location)
        }

        return lexer.pop()
    }
}
