import PackageDescription

let beta = Version(2,0,0, prereleaseIdentifiers: ["beta"])

let package = Package(
    name: "MySQL",
    dependencies: [
        // Module map for `libmysql`
        .Package(url: "https://github.com/vapor/cmysql.git", beta),

        // Data structure for converting between multiple representations
        .Package(url: "https://github.com/vapor/node.git", beta),

        // Core extensions, type-aliases, and functions that facilitate common tasks
        .Package(url: "https://github.com/vapor/core.git", beta),

        // JSON parsing and serialization for storing arrays and objects in MySQL
        .Package(url: "https://github.com/vapor/json.git", beta)
    ]
)
