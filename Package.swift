// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "cte",
    dependencies: [
       .package(url: "https://github.com/trill-lang/cllvm.git", from: "0.0.0"),
    ],
    targets: [
        .target(name: "cte", dependencies: []),
    ]
)
