// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "mysql-kit",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library(name: "MySQLKit", targets: ["MySQLKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/mysql-nio.git", from: "1.7.2"),
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.29.3"),
        .package(url: "https://github.com/vapor/async-kit.git", from: "1.19.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", "2.0.0" ..< "4.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.26.0"),
    ],
    targets: [
        .target(
            name: "MySQLKit",
            dependencies: [
                .product(name: "AsyncKit", package: "async-kit"),
                .product(name: "MySQLNIO", package: "mysql-nio"),
                .product(name: "SQLKit", package: "sql-kit"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "MySQLKitTests",
            dependencies: [
                .product(name: "SQLKitBenchmark", package: "sql-kit"),
                .target(name: "MySQLKit"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ConciseMagicFile"),
    .enableUpcomingFeature("ForwardTrailingClosures"),
] }
