
import LLVM
import func Darwin.C.exit
import func Darwin.C.realpath
import func Darwin.C.dirname

var knownSourceFiles: [String: SourceFile] = [:]

public final class SourceFile {

    weak var firstImportedFrom: SourceFile?
    var isInitialFile: Bool {
        return firstImportedFrom == nil
    }

    var nodes: [AstNode] = []

    let lexer: Lexer
    var fullpath: String

    var hasBeenParsed: Bool = false
    var hasBeenChecked: Bool = false
    var hasBeenGenerated: Bool = false

    var pathFirstImportedAs: String
    var importStatements: [AstNode] = []

    // Set in Checker
    var scope: Scope!
    var linkedLibraries: Set<String> = []

    init(lexer: Lexer, fullpath: String, pathImportedAs: String, importedFrom: SourceFile?) {
        self.lexer = lexer
        self.fullpath = fullpath
        self.pathFirstImportedAs = pathImportedAs
        self.firstImportedFrom = importedFrom
    }

    /// - Returns: nil iff the file could not be located or opened for reading
    public static func new(path: String, importedFrom: SourceFile? = nil) -> SourceFile? {

        var pathRelativeToInitialFile = path

        if let importedFrom = importedFrom {
            pathRelativeToInitialFile = importedFrom.fullpath.dirname + path
        }

        guard let fullpathC = realpath(pathRelativeToInitialFile, nil) else {
            return nil
        }

        let fullpath = String(cString: fullpathC)

        if let existing = knownSourceFiles[fullpath] {
            return existing
        }

        guard let file = File(absolutePath: fullpath) else {
            return nil
        }
        let lexer = Lexer(file)

        let sourceFile = SourceFile(lexer: lexer, fullpath: fullpath, pathImportedAs: path, importedFrom: importedFrom)
        knownSourceFiles[fullpath] = sourceFile

        return sourceFile
    }

    var moduleObjFilepath: String {
        return buildDirectory + moduleName + ".o"
    }

    public func parseEmittingErrors() {
        assert(!hasBeenParsed)
        var parser = Parser(file: self)
        self.nodes = parser.parse()

        let importedFiles = importStatements.map({ $0.asImport.file })

        for importedFile in importedFiles {
            guard !importedFile.hasBeenParsed else {
                continue
            }
            importedFile.parseEmittingErrors()
        }
        emitErrors(for: "Parsing")

        hasBeenParsed = true
    }

    public func checkEmittingErrors() {
        guard !hasBeenChecked else {
            return
        }
        // checks importted files when needed
        var checker = Checker(file: self)
        scope = checker.context.scope
        checker.check() // Changes node values to checked values
        emitErrors(for: "Checking")

        hasBeenChecked = true
    }

    public func generateIntermediateRepresentation() {

        SourceFile.generateIntermediateRepresentation(to: module, for: self)
    }

    public func validateIntermediateRepresentation() {
        do {
            try module.verify()
        } catch {
            try! module.print(to: "/dev/stdout")
            print(error)
            exit(1)
        }
    }

    public func compileIntermediateRepresentation() {
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

    public func link() {
        let clangPath = getClangPath()

        var args = ["-o", moduleName, moduleObjFilepath]
        for library in linkedLibraries {
            if library.hasSuffix(".framework") {

                let frameworkName = library.components(separatedBy: ".").first!

                args.append("-framework")
                args.append(frameworkName)

                guard library == library.basename else {
                    print("ERROR: Only system frameworks are supported")
                    exit(1)
                }
            } else {
                args.append(library)
            }
        }

        shell(path: clangPath, args: ["-o", moduleName, moduleObjFilepath])
    }

    public func cleanupBuildProducts() {
        do {
            try removeFile(at: buildDirectory)
        } catch {
            print("ERROR: \(error)")
            print("  While cleaning up build directory")
            exit(1)
        }
    }

    public func emitIr() {
        do {
            try module.print(to: "/dev/stdout")
        } catch {
            print("ERROR: \(error)")
            print("  While emitting IR to '/dev/stdout'")
            exit(1)
        }
    }

    public func emitBitcode() {
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

    public func emitAssembly() {
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

   public static func generateIntermediateRepresentation(to module: Module, for file: SourceFile) {
        assert(file.hasBeenChecked)
        assert(!file.hasBeenGenerated)

        let importedFiles = file.importStatements.map({ $0.asImport.file })

        for importedFile in importedFiles {
            guard !importedFile.hasBeenGenerated else {
                continue
            }

            generateIntermediateRepresentation(to: module, for: importedFile)
        }

        var irGenerator = IRGenerator(file: file)
        irGenerator.generate()

        file.hasBeenGenerated = true
    }
}
