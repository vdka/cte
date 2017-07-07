
import Foundation
import LLVM

guard CommandLine.arguments.count > 1 else {
    print("ERROR: No input file")
    exit(1)
}

let filepath = CommandLine.arguments[1]
guard let file = SourceFile.new(path: filepath) else {
    print("ERROR: No such file or directory '\(filepath)'")
    exit(1)
}

var options = Options.from(arguments: CommandLine.arguments[2...])

performCompilationPreflightChecks(with: options)

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

if !options.contains(.noCleanup) {
    file.cleanupBuildProducts()
}

if options.contains(.emitIr) {
    file.emitIr()
}

if options.contains(.emitBitcode) {
    file.emitBitcode()
}

if options.contains(.emitAssembly) {
    file.emitAssembly()
}

if options.contains(.emitTiming) {
    var total = 0.0
    for (name, duration) in timings {
        total += duration
        print("\(name) took \(String(format: "%.3f", duration)) seconds")
    }
    print("Total time was \(String(format: "%.3f", total)) seconds")
}
