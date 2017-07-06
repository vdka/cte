
import LLVM
import func Darwin.C.exit

final class SourceFile {

    weak var importedFrom: SourceFile?

    var nodes: [AstNode] = []

    let lexer: Lexer
    var fullpath: String
    var importedPath: String
    var importedFiles: [SourceFile] = []

    var moduleName: String!
    var module: Module!

    var scope: Scope?

    init?(path: String) {
        guard let file = File(path: filepath) else {
            return nil
        }
        self.lexer = Lexer(file)

        self.importedPath = filepath
        self.fullpath = file.fullpath
    }

    var moduleObjFilepath: String {
        return buildDirectory + moduleName + ".o"
    }

    func parseEmittingErrors() {
        var parser = Parser(lexer: lexer, state: [])
        self.nodes = parser.parse()
        emitErrors(for: "Parsing")
    }

    func checkEmittingErrors() {
        for importedFile in importedFiles {
            importedFile.checkEmittingErrors()
        }
        var checker = Checker(nodes: nodes)
        checker.check() // Changes node values to checked values
        emitErrors(for: "Checking")
    }

    func generateIntermediateRepresentation() {

        assert(fullpath.hasSuffix(".cte"))

        moduleName = importedPath.split(separator: "/")
            .last!.split(separator: ".").first!

        let module = Module(name: moduleName)

        for importedFile in importedFiles {
            SourceFile.generateIntermediateRepresentation(to: module, for: importedFile)
        }

        SourceFile.generateIntermediateRepresentation(to: module, for: self)

        self.module = module
    }

    func validateIntermediateRepresentation() {
        do {
            try module.verify()
        } catch {
            print(error)
            module.dump()
            exit(1)
        }
    }

    func compileIntermediateRepresentation() {
        do {
            try targetMachine.emitToFile(
                module: module,
                type: .object,
                path: moduleObjFilepath
            )
        } catch {
            print("ERROR: \(error)")
            print("  While emitting object file to \(moduleObjFilepath)")
            exit(1)
        }
    }

    func link() {
        let clangPath = getClangPath()
        shell(path: clangPath, args: ["-o", moduleName, moduleObjFilepath])
    }

    func cleanupBuildProducts() {
        do {
            try removeFile(at: buildDirectory)
        } catch {
            print("ERROR: \(error)")
            print("  While cleaning up build directory")
            exit(1)
        }
    }

    func emitIr() {
        do {
            try module.print(to: "/dev/stdout")
        } catch {
            print("ERROR: \(error)")
            print("  While emitting IR")
            exit(1)
        }
    }

    func emitBitcode() {
        do {
            try targetMachine.emitToFile(
                module: module,
                type: .bitCode,
                path: "/dev/stdout"
            )
        } catch {
            print("ERROR: \(error)")
            print("  While emitting Bitcode")
            exit(1)
        }
    }

    func emitAssembly() {
        do {
            try targetMachine.emitToFile(
                module: module,
                type: .assembly,
                path: "/dev/stdout"
            )
        } catch {
            print("ERROR: \(error)")
            print("  While emitting Assembly")
            exit(1)
        }
    }

    static func generateIntermediateRepresentation(to module: Module, for file: SourceFile) {

        for importedFile in file.importedFiles {
            generateIntermediateRepresentation(to: module, for: importedFile)
        }

        let irGenerator = IRGenerator(forModule: module, nodes: file.nodes)
        irGenerator.generate()
    }
}
