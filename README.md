<img src="https://user-images.githubusercontent.com/1342803/75589537-fbfc9100-5a48-11ea-8732-e75dfe32e338.png" height="64" alt="MySQL">

<a href="https://docs.vapor.codes/4.0/">
    <img src="http://img.shields.io/badge/read_the-docs-2196f3.svg" alt="Documentation">
</a>
<a href="https://discord.gg/vapor">
    <img src="https://img.shields.io/discord/431917998102675485.svg" alt="Team Chat">
</a>
<a href="LICENSE">
    <img src="http://img.shields.io/badge/license-MIT-brightgreen.svg" alt="MIT License">
</a>
<a href="https://github.com/vapor/sql-kit/actions">
    <img src="https://github.com/vapor/sql-kit/workflows/test/badge.svg" alt="Continuous Integration">
</a>
<a href="https://swift.org">
    <img src="http://img.shields.io/badge/swift-5.2-brightgreen.svg" alt="Swift 5.2">
</a>
<br>
<br>

🐬 Non-blocking, event-driven Swift client for MySQL.

### Major Releases

The table below shows a list of PostgresKit major releases alongside their compatible NIO and Swift versions. 

|Version|NIO|Swift|SPM|
|---|---|---|---|
|4.0|2.0|5.2+|`from: "4.0.0"`|
|3.0|1.0|4.0+|`from: "3.0.0"`|
|2.0|N/A|3.1+|`from: "2.0.0"`|
|1.0|N/A|3.1+|`from: "1.0.0"`|

Use the SPM string to easily include the dependendency in your `Package.swift` file.

### Supported Platforms

MySQLKit supports the following platforms:

- Ubuntu 16.04+
- macOS 10.15+

## Overview

MySQLKit is a MySQL client library built on [SQLKit](https://github.com/vapor/sql-kit). It supports building and serializing MySQL-dialect SQL queries. MySQLKit uses [MySQLNIO](https://github.com/vapor/mysql-nio) to connect and communicate with the database server asynchronously. [AsyncKit](https://github.com/vapor/async-kit) is used to provide connection pooling. 

### Configuration

Database connection options and credentials are specified using a `MySQLConfiguration` struct. 

```swift
import MySQLKit

let configuration = MySQLConfiguration(
    hostname: "localhost",
    port: 3306,
    username: "vapor_username",
    password: "vapor_password",
    database: "vapor_database"
)
```

URL string based configuration is also supported.

```swift
guard let configuration = MySQLConfiguration(url: "mysql://...") else {
    ...
}
```

To connect via unix-domain sockets, use `unixDomainSocketPath` instead of `hostname` and `port`.

```swift
let configuration = MySQLConfiguration(
    unixDomainSocketPath: "/path/to/socket",
    username: "vapor_username",
    password: "vapor_password",
    database: "vapor_database"
)
```

### Connection Pool

Once you have a `MySQLConfiguration`, you can use it to create a connection source and pool.

```swift
let eventLoopGroup: EventLoopGroup = ...
defer { try! eventLoopGroup.syncShutdown() }

let pools = EventLoopGroupConnectionPool(
    source: MySQLConnectionSource(configuration: configuration), 
    on: eventLoopGroup
)
defer { pools.shutdown() }
```

First create a `MySQLConnectionSource` using the configuration struct. This type is responsible for creating new connections to your database server as needed.

Next, use the connection source to create an `EventLoopGroupConnectionPool`. You will also need to pass an `EventLoopGroup`. For more information on creating an `EventLoopGroup`, visit SwiftNIO's [documentation](https://apple.github.io/swift-nio/docs/current/NIO/index.html). Make sure to shutdown the connection pool before it deinitializes. 

`EventLoopGroupConnectionPool` is a collection of pools for each event loop. When using `EventLoopGroupConnectionPool` directly, random event loops will be chosen as needed.

```swift
pools.withConnection { conn 
    print(conn) // MySQLConnection on randomly chosen event loop
}
```

To get a pool for a specific event loop, use `pool(for:)`. This returns an `EventLoopConnectionPool`. 

```swift
let eventLoop: EventLoop = ...
let pool = pools.pool(for: eventLoop)

pool.withConnection { conn
    print(conn) // MySQLConnection on eventLoop
}
```

### MySQLDatabase

Both `EventLoopGroupConnectionPool` and `EventLoopConnectionPool` can be used to create instances of `MySQLDatabase`.

```swift
let mysql = pool.database(logger: ...) // MySQLDatabase
let rows = try mysql.simpleQuery("SELECT @@version;").wait()
```

Visit [MySQLNIO's docs](https://github.com/vapor/mysql-nio) for more information on using `MySQLDatabase`.

### SQLDatabase

A `MySQLDatabase` can be used to create an instance of `SQLDatabase`.

```swift
let sql = mysql.sql() // SQLDatabase
let planets = try sql.select().column("*").from("planets").all().wait()
```

Visit [SQLKit's docs](https://github.com/vapor/sql-kit) for more information on using `SQLDatabase`. 