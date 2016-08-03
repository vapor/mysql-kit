import PackageDescription

let package = Package(
    name: "MySQL",
    dependencies: [
        .Package(url: "https://github.com/collinhundley/CMariaDB.git", majorVersion: 0, minor: 1)
    ]
)
