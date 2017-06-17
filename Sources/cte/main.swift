
assert(CommandLine.arguments.count > 1)
let filepath = CommandLine.arguments[1]
guard let file = File(path: filepath) else {
    fatalError("Needs file.")
}

var lexer = Lexer(file)

var parser = Parser(lexer: lexer, state: [])
emitErrors(for: "Parsing")

let nodes = parser.parse()

print(nodes.map({ $0.description }).joined(separator: "\n"))

declareBuiltins()

var checker = Checker(nodes: nodes)

let info = checker.check()
emitErrors(for: "Checking")

print(info)
