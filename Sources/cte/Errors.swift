
import func Darwin.C.stdlib.exit

var errors: [String] = []
var notes: [Int: [String]] = [:]

func attachNote(_ message: String) {
    assert(!errors.isEmpty)

    guard var existingNotes = notes[errors.lastIndex] else {
        notes[errors.lastIndex] = [message]
        return
    }
    existingNotes.append(message)
    notes[errors.lastIndex] = existingNotes
}

func reportError(_ message: String, at node: AstNode, file: StaticString = #file, line: UInt = #line) {

    guard let firstToken = node.tokens.first else {
        fatalError()
    }
    let formatted = formatMessage(message, firstToken.start.description, file, line)

    errors.append(formatted)
}

func reportError(_ message: String, at token: Token, file: StaticString = #file, line: UInt = #line) {

    let formatted = formatMessage(message, token.start.description, file, line)
    errors.append(formatted)
}

func reportError(_ message: String, at lexer: Lexer, file: StaticString = #file, line: UInt = #line) {

    let formatted = formatMessage(message, lexer.location.description, file, line)
    errors.append(formatted)
}

func emitErrors(for stage: String) {
    guard !cte.errors.isEmpty else {
        return
    }

    let errors = cte.errors.enumerated().filter { !$0.element.contains("<invalid>") }

    print("There were \(errors.count) errors during \(stage)\nexiting")

    for error in errors {
        print(error.element)
        if let notes = notes[error.offset] {
            for note in notes {
                print("  " + note)
            }
        }
        print()
    }
    exit(1)
}

fileprivate func formatMessage(severity: String = "ERROR", _ message: String, _ location: String, _ file: StaticString, _ line: UInt) -> String {
    var formatted = severity + "(" + location.description + ")" + ": " + message

    #if DEBUG
        formatted = formatted + "\n\traised on line \(line) of \(String(describing: file).basename)"
    #endif

    return formatted
}

