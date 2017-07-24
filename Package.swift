// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "cte",
    dependencies: [
       .package(url: "https://github.com/vdka/LLVMSwift.git", .branch("master")),
    ],
    targets: [
        .target(name: "cte", dependencies: ["Core"]),
        .target(name: "Core", dependencies: ["LLVM"]),
        .testTarget(name: "CoreTests", dependencies: ["Core"])
    ],
    swiftLanguageVersions: [4]
)
