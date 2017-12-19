// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "MySQL",
    products: [
        .library(name: "MySQL", targets: ["MySQL"]),
    ],
    dependencies: [
        // Swift Promises, Futures, and Streams.
        .package(url: "https://github.com/vapor/async.git", .branch("beta")),

        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/core.git", .branch("beta")),

        // Cryptography modules
        .package(url: "https://github.com/vapor/crypto.git", .branch("beta")),

        // Non-blocking networking for Swift (HTTP and WebSockets).
        .package(url: "https://github.com/vapor/engine.git", .branch("beta")),
    ],
    targets: [
        .target(name: "MySQL", dependencies: ["CodableKit", "Crypto", "TCP", "TLS"]),
        .testTarget(name: "MySQLTests", dependencies: ["MySQL"]),
    ]
)


