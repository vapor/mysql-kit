// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "mysql-kit",
    products: [
        .library(name: "MySQLKit", targets: ["MySQLKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/mysql-nio.git", .branch("master")),
        .package(url: "https://github.com/vapor/sql-kit.git", .branch("master")),
        .package(url: "https://github.com/vapor/async-kit.git", .branch("master")),

    ],
    targets: [
        .target(name: "MySQLKit", dependencies: ["AsyncKit", "MySQLNIO", "SQLKit"]),
        .testTarget(name: "MySQLKitTests", dependencies: ["MySQLKit", "SQLKitBenchmark"]),
    ]
)
