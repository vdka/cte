

assert(CommandLine.arguments.count > 1)
let filepath = CommandLine.arguments[1]
guard let file = File(path: filepath) else {
    fatalError("Needs file.")
}

var lexer = Lexer(file)

var parser = Parser(lexer: lexer, state: [])

let nodes = parser.parse()

print(nodes.map({ $0.description }).joined(separator: "\n"))

var checker = Checker(nodes: nodes)
