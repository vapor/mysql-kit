// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "mysql-kit",
    products: [
        .library(name: "MySQLKit", targets: ["MySQLKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/nio-mysql.git", .branch("master")),
        .package(url: "https://github.com/vapor/sql.git", .branch("master")),
        .package(url: "https://github.com/vapor/nio-kit.git", .branch("master")),

    ],
    targets: [
        .target(name: "MySQLKit", dependencies: ["NIOKit", "NIOMySQL", "SQLKit"]),
        .testTarget(name: "MySQLKitTests", dependencies: ["MySQLKit", "SQLKitBenchmark"]),
    ]
)
