// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "MySQL",
    products: [
        .library(name: "MySQL", targets: ["MySQL"]),
    ],
    dependencies: [
        // Swift Promises, Futures, and Streams.
        .package(url: "https://github.com/vapor/async.git", .exact("1.0.0-beta.1")),

        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/core.git", .exact("3.0.0-beta.1")),

        // Cryptography modules
        .package(url: "https://github.com/vapor/crypto.git", .exact("3.0.0-beta.1")),
        
        // Networking
        .package(url: "https://github.com/vapor/sockets.git", .exact("3.0.0-beta.2")),

        // SSL support
        .package(url: "https://github.com/vapor/tls.git", .exact("3.0.0-beta.2")),
    ],
    targets: [
        .target(name: "MySQL", dependencies: ["CodableKit", "Crypto", "TCP", "TLS"]),
        .testTarget(name: "MySQLTests", dependencies: ["MySQL"]),
    ]
)
