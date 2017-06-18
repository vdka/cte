
import Foundation
import LLVM

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

checker.check() // Changes nodes to Checked variants where appropriate
emitErrors(for: "Checking")

let irgen = IRGenerator(forModuleNamed: "main", nodes: nodes)
irgen.generate()

do {
    try irgen.module.verify()
    try TargetMachine().emitToFile(module: irgen.module, type: .object, path: FileManager.default.currentDirectoryPath + "/main.o")

    let clangPath = getClangPath()
    shell(path: clangPath, args: ["-o", "main", "main.o"])

} catch {
    print(error)

    irgen.module.dump()
}



//print(checker.nodes)

