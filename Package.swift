import PackageDescription

let package = Package(
    name: "MySQL",
    dependencies: [
        .Package(url: "https://github.com/collinhundley/cmysql.git", majorVersion: 0, minor: 2)
    ]
)
