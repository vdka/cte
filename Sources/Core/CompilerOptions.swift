
public struct Options: OptionSet {
    public static var instance: Options = []

    public let rawValue: UInt16

    public static let noCleanup    = Options(rawValue: 0b0000_0001)

    public static let emitTiming   = Options(rawValue: 0b0001_0000)
    public static let emitIr       = Options(rawValue: 0b0010_0000)
    public static let emitBitcode  = Options(rawValue: 0b0100_0000)
    public static let emitAssembly = Options(rawValue: 0b1000_0000)

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static func from(arguments: ArraySlice<String>) -> Options {
        var value: Options = []

        for arg in arguments {

            switch arg {
            case "-no-cleanup":
                value.insert(.noCleanup)
            case "-emit-timing":
                value.insert(.emitTiming)
            case "-emit-ir":
                value.insert(.emitIr)
            case "-emit-bitcode":
                value.insert(.emitBitcode)
            case "-emit-asm", "-S":
                value.insert(.emitAssembly)
            default:
                print("WARNING: argument unused during compilation: '\(arg)'")
            }
        }

        return value
    }
}
