// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "cte",
    dependencies: [
       .package(url: "https://github.com/trill-lang/LLVMSwift.git", .exact("0.1.11")),
    ],
    targets: [
        .target(name: "cte", dependencies: ["LLVM"]),
    ]
)
