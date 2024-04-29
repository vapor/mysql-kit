<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/vapor/mysql-kit/assets/1130717/d5582d0a-f8b2-4fab-aeea-79b170bebc28">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/vapor/mysql-kit/assets/1130717/71d0fa71-5ded-492c-9657-4206f233419e">
  <img src="https://github.com/vapor/mysql-kit/assets/1130717/71d0fa71-5ded-492c-9657-4206f233419e" height="96" alt="MySQLKit">
</picture> 
<br>
<br>
<a href="https://docs.vapor.codes/4.0/"><img src="https://design.vapor.codes/images/readthedocs.svg" alt="Documentation"></a>
<a href="https://discord.gg/vapor"><img src="https://design.vapor.codes/images/discordchat.svg" alt="Team Chat"></a>
<a href="LICENSE"><img src="https://design.vapor.codes/images/mitlicense.svg" alt="MIT License"></a>
<a href="https://github.com/vapor/mysql-kit/actions/workflows/test.yml"><img src="https://img.shields.io/github/actions/workflow/status/vapor/mysql-kit/test.yml?event=push&style=plastic&logo=github&label=tests&logoColor=%23ccc" alt="Continuous Integration"></a>
<a href="https://codecov.io/github/vapor/mysql-kit"><img src="https://img.shields.io/codecov/c/github/vapor/mysql-kit?style=plastic&logo=codecov&label=codecov"></a>
<a href="https://swift.org"><img src="https://design.vapor.codes/images/swift58up.svg" alt="Swift 5.8+"></a>
</p>

<br>

MySQLKit is an [SQLKit] driver for MySQL clients. It supports building and serializing MySQL-dialect SQL queries. MySQLKit uses [MySQLNIO] to connect and communicate with the database server asynchronously. [AsyncKit] is used to provide connection pooling.

[SQLKit]: https://github.com/vapor/sql-kit
[MySQLNIO]: https://github.com/vapor/mysql-nio
[AsyncKit]: https://github.com/vapor/async-kit

### Usage

Use the SPM string to easily include the dependendency in your `Package.swift` file.

```swift
.package(url: "https://github.com/vapor/mysql-kit.git", from: "4.0.0")
```

### Supported Platforms

MySQLKit supports the following platforms:

- Ubuntu 20.04+
- macOS 10.15+

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

Visit [SQLKit's docs](https://api.vapor.codes/sqlkit/documentation/sqlkit) for more information on using `SQLDatabase`. 
