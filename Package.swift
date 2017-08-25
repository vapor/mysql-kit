// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "MySQL",
    products: [
        .library(name: "MySQL", targets: ["MySQL"])
    ],
    dependencies: [
        // Core extensions, type-aliases, and functions that facilitate common tasks
        .package(url: "https://github.com/vapor/Engine.git", .revision("beta")),
        .package(url: "https://github.com/vapor/Crypto.git", .revision("rework")),
    ],
    targets: [
        .target(name: "MySQL", dependencies: ["TCP", "Crypto"]),
        .testTarget(name: "MySQLTests", dependencies: ["MySQL"])
    ]
)

/// INFO:
/// https://www.safaribooksonline.com/library/view/understanding-mysql-internals/0596009577/ch04s04.html
