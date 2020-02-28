// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "mysql-kit",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .library(name: "MySQLKit", targets: ["MySQLKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/mysql-nio.git", from: "1.0.0-beta.2"),
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.0.0-beta.2"),
        .package(url: "https://github.com/vapor/async-kit.git", from: "1.0.0-rc.1"),

    ],
    targets: [
        .target(name: "MySQLKit", dependencies: ["AsyncKit", "MySQLNIO", "SQLKit"]),
        .testTarget(name: "MySQLKitTests", dependencies: ["MySQLKit", "SQLKitBenchmark"]),
    ]
)
