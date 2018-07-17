// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "MySQL",
    products: [
        .library(name: "MySQL", targets: ["MySQL"]),
    ],
    dependencies: [
        // 🌎 Utility package containing tools for byte manipulation, Codable, OS APIs, and debugging.
        .package(url: "https://github.com/vapor/core.git", from: "3.0.0"),
        
        // 🔑 Hashing (BCrypt, SHA, HMAC, etc), encryption, and randomness.
        .package(url: "https://github.com/vapor/crypto.git", from: "3.0.0"),

        // 🗄 Core services for creating database integrations.
        .package(url: "https://github.com/vapor/database-kit.git", from: "1.2.0"),

        // 📦 Dependency injection / inversion of control framework.
        .package(url: "https://github.com/vapor/service.git", from: "1.0.0"),
        
        // Event-driven network application framework for high performance protocol servers & clients, non-blocking.
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.0.0"),

        // Bindings to OpenSSL-compatible libraries for TLS support in SwiftNIO
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "1.0.0"),
        
        // *️⃣ Build SQL queries in Swift. Extensible, protocol-based design that supports DQL, DML, and DDL.
        .package(url: "https://github.com/vapor/sql.git", from: "2.0.0"),

    ],
    targets: [
        .target(name: "MySQL", dependencies: [
            "Async", "Bits", "Core", "Crypto", "DatabaseKit", "NIO", "NIOOpenSSL", "Service", "SQL"
        ]),
        .testTarget(name: "MySQLTests", dependencies: ["Crypto", "MySQL", "SQLBenchmark"]),
    ]
)
