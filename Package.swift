// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "MySQL",
    products: [
        .library(name: "MySQL", targets: ["MySQL"]),
    ],
    dependencies: [
        // Swift Promises, Futures, and Streams.
        .package(url: "https://github.com/vapor/async.git", from: "1.0.0-rc"),

        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/core.git", from: "3.0.0-rc"),

        // Cryptography modules
        .package(url: "https://github.com/vapor/crypto.git", from: "3.0.0-rc"),

        // Networking
        .package(url: "https://github.com/vapor/sockets.git", from: "3.0.0-rc"),

        // SSL support
        .package(url: "https://github.com/vapor/tls.git", from: "3.0.0-rc"),
    ],
    targets: [
        .target(name: "MySQL", dependencies: ["CodableKit", "Crypto", "TCP", "TLS"]),
        .testTarget(name: "MySQLTests", dependencies: ["MySQL"]),
    ]
)
