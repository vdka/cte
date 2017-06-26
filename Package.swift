// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "cte",
    dependencies: [
       .package(url: "https://github.com/vdka/LLVMSwift.git", .branch("comparisons-are-binary")),
    ],
    targets: [
        .target(name: "cte", dependencies: ["LLVM"]),
    ],
    swiftLanguageVersions: [4]
)
