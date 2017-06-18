
import Foundation
import LLVM

assert(CommandLine.arguments.count > 1)
let filepath = CommandLine.arguments[1]
guard let file = File(path: filepath) else {
    fatalError("Needs file.")
}

var options = CommandLine.arguments[2...]

startTiming("Parsing")
var lexer = Lexer(file)
var parser = Parser(lexer: lexer, state: [])
let nodes = parser.parse()
emitErrors(for: "Parsing")
endTiming()

startTiming("Checking")
declareBuiltins()
var checker = Checker(nodes: nodes)
checker.check() // Changes nodes to Checked variants where appropriate
emitErrors(for: "Checking")
endTiming()

startTiming("IR Generation")
let irgen = IRGenerator(forModuleNamed: "main", nodes: nodes)
irgen.generate()
endTiming()

do {

    startTiming("IR Validation")
    try irgen.module.verify()
    endTiming()

    startTiming("IR Emission")
    try TargetMachine().emitToFile(module: irgen.module, type: .object, path: FileManager.default.currentDirectoryPath + "/main.o")
    endTiming()

    startTiming("Linking (via shell)")
    let clangPath = getClangPath()
    shell(path: clangPath, args: ["-o", "main", "main.o"])
    endTiming()

    if options.contains("-emit-ir") {
        irgen.module.dump()
    }

} catch {
    print(error)

    irgen.module.dump()
}

var total = 0.0
for timing in timings {
    total += timing.duration
    print("\(timing.name) took \(String(format: "%.3f", timing.duration)) seconds")
}
print("Total time was \(String(format: "%.3f", total)) seconds")
