import PackageDescription

let package = Package(
    name: "MySQL",
    dependencies: [
        // Module map for `libmysql`
        .Package(url: "https://github.com/vapor/cmysql.git", majorVersion: 1),

        // Data structure for converting between multiple representations
        .Package(url: "https://github.com/vapor/node.git", Version(2,0,0, prereleaseIdentifiers: ["alpha"])),

        // Core extensions, type-aliases, and functions that facilitate common tasks
        .Package(url: "https://github.com/vapor/core.git", Version(2,0,0, prereleaseIdentifiers: ["alpha"])),

        // JSON parsing and serialization for storing arrays and objects in MySQL
        .Package(url: "https://github.com/vapor/json.git", Version(2,0,0, prereleaseIdentifiers: ["alpha"]))
    ]
)
