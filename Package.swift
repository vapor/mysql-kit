import PackageDescription

let package = Package(
    name: "MySQL",
    dependencies: [
        // Module map for `libmysql`
        .Package(url: "https://github.com/qutheory/cmysql.git", majorVersion: 0, minor: 2),

        // Data structure for converting between multiple representations
        .Package(url: "https://github.com/qutheory/node.git", majorVersion: 0, minor: 2)
    ]
)
