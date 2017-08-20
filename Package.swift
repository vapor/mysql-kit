// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "MySQL",
    products: [
        .library(name: "MySQL", targets: ["MySQL"])
    ],
    dependencies: [
        // Core extensions, type-aliases, and functions that facilitate common tasks
        .package(url: "https://github.com/vapor/Engine.git", .revision("serializer")),
    ],
    targets: [
        .target(name: "MySQL", dependencies: ["TCP"])
    ]
)
