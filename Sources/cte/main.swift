import Core
import LLVM
import Foundation


guard CommandLine.arguments.count > 1 else {
    print("ERROR: No input file")
    exit(1)
}

let filepath = CommandLine.arguments[1]
guard let file = SourceFile.new(path: filepath) else {
    print("ERROR: No such file or directory '\(filepath)'")
    exit(1)
}

Options.instance = Options.from(arguments: CommandLine.arguments[2...])

performCompilationPreflightChecks(with: Options.instance)

startTiming("Parsing")
file.parseEmittingErrors()
endTiming()

startTiming("Checking")
file.checkEmittingErrors()
endTiming()

startTiming("IR Generation")
file.generateIntermediateRepresentation()
endTiming()

startTiming("IR Validation")
file.validateIntermediateRepresentation()
endTiming()

startTiming("IR Compilation")
file.compileIntermediateRepresentation()
endTiming()

startTiming("Linking (via shell)")
file.link()
endTiming()

if !Options.instance.contains(.noCleanup) {
    file.cleanupBuildProducts()
}

if Options.instance.contains(.emitIr) {
    file.emitIr()
}

if Options.instance.contains(.emitBitcode) {
    file.emitBitcode()
}

if Options.instance.contains(.emitAssembly) {
    file.emitAssembly()
}

if Options.instance.contains(.emitTiming) {
    var total = 0.0
    for (name, duration) in timings {
        total += duration
        print("\(name) took \(String(format: "%.3f", duration)) seconds")
    }
    print("Total time was \(String(format: "%.3f", total)) seconds")
}
