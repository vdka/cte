
struct PrefixOperator {

    let symbol: Token.Kind
    let nud: ((inout Parser) -> AstNode)

    init(_ symbol: Token.Kind, nud: ((inout Parser) -> AstNode)? = nil) {

        let nud = nud ?? { parser in
            let token = parser.advance()

            assert(token.kind == symbol)

            let expr = parser.expression(70)

            let val = AstNode.Prefix(token: token, expr: expr)
            return AstNode(val, tokens: [token])
        }

        self.symbol = symbol
        self.nud = nud
    }
}

extension PrefixOperator {

    static var table: [PrefixOperator] = [
        PrefixOperator(.plus),
        PrefixOperator(.minus),
        PrefixOperator(.asterix, nud: { parser in
            let asterixToken = parser.advance()
            let pointee = parser.expression()
            let pointer = AstNode.PointerType(pointee: pointee)
            return AstNode(pointer, tokens: [asterixToken])
        }),
        PrefixOperator(.lt),
        PrefixOperator(.ampersand),
    ]

    static func lookup(_ symbol: Token.Kind) -> PrefixOperator? {
        return table.first(where: { $0.symbol == symbol })
    }
}

struct InfixOperator {

    let symbol: Token.Kind
    let lbp: UInt8
    let associativity: Associativity

    let led: ((inout Parser, AstNode) -> AstNode)

    enum Associativity { case left, right }

    init(
        _ symbol: Token.Kind,
        bindingPower lbp: UInt8, associativity: Associativity = .left,
        led: ((inout Parser, _ left: AstNode) -> AstNode)? = nil
    ) {

        let led = led ?? { parser, lhs in
            let token = parser.advance()
            let bp = (associativity == .left) ? lbp : lbp - 1

            let rhs = parser.expression(bp)

            let val = AstNode.Infix(token: token, lhs: lhs, rhs: rhs)

            return AstNode(val, tokens: [token])
        }

        self.symbol = symbol
        self.lbp = lbp
        self.associativity = associativity
        self.led = led
    }
}

extension InfixOperator {

    static var table: [InfixOperator] = [
        InfixOperator(.plus, bindingPower: 70),
        InfixOperator(.minus, bindingPower: 70),
        InfixOperator(.asterix, bindingPower: 80),
        InfixOperator(.divide, bindingPower: 80),

        // Conditionals
        InfixOperator(.lt, bindingPower: 40),
        InfixOperator(.gt, bindingPower: 40),
        InfixOperator(.lte, bindingPower: 40),
        InfixOperator(.gte, bindingPower: 40),

        // Assignment macros
        InfixOperator(.plusEquals, bindingPower: 70, led: InfixOperator.expandAssignmentMacro),
        InfixOperator(.minusEquals, bindingPower: 70, led: InfixOperator.expandAssignmentMacro),
        InfixOperator(.asterixEquals, bindingPower: 80, led: InfixOperator.expandAssignmentMacro),
        InfixOperator(.divideEquals, bindingPower: 80, led: InfixOperator.expandAssignmentMacro),
    ]

    /// expands assignment macros to their verbose form (I.e. `i += 1` to `i = i + 1`).
    static func expandAssignmentMacro(_ parser: inout Parser, _ lhs: AstNode) -> AstNode {
        let token = Token.getOperatorFor(assignMacro: parser.advance())
        let rhs = parser.expression()

        let val =  AstNode(AstNode.Infix(token: token, lhs: lhs, rhs: rhs), tokens: [token])
        return AstNode(AstNode.Assign(lvalue: lhs, rvalue:val), tokens: [token])
    }

    static func lookup(_ symbol: Token.Kind) -> InfixOperator? {
        return table.first(where: { $0.symbol == symbol })
    }
}

extension Token {
    static func getOperatorFor(assignMacro: Token) -> Token {
        let kind: Token.Kind

        switch assignMacro.kind {
        case .plusEquals:       kind = .plus
        case .minusEquals:      kind = .minus
        case .asterixEquals:    kind = .asterix
        case .divideEquals:     kind = .divide
        default:
            fatalError("`\(assignMacro)` is not an assignment macro")
        }

        return Token(kind: kind, value: assignMacro.value, location: assignMacro.location)
    }
}
