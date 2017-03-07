# MySQL for Swift

[![Swift](http://img.shields.io/badge/swift-3.1-brightgreen.svg)](https://swift.org)
[![CircleCI](https://circleci.com/gh/vapor/mysql.svg?style=shield)](https://circleci.com/gh/vapor/mysql)
[![Slack Status](http://vapor.team/badge.svg)](http://vapor.team)

A Swift wrapper for MySQL.

- [x] Prepared statements
- [x] Transactions
- [x] Helpful errors
- [x] Tested

This wrapper uses the latest MySQL fetch API to enable performant prepared statements and output bindings. Data is sent to and received from the MySQL server in its native data type without converting to and from strings. 

The Swift wrappers around the MySQL's C structs and pointers automatically manage closing connections and deallocating memeory. 

## 📖 Examples

### Database Connector

Create a database connector using your MySQL credentials and address information.

```swift
import MySQL

let mysql = try MySQL.Database(
    host: "127.0.0.1",
    user: "root",
    password: "",
    database: "test"
)
```

There are several additional arguments that can be passed to the database connector's init.

```swift
MySQL.Database.init(
    host: String,
    user: String,
    password: String,
    database: String,
    port: UInt = 3306,
    socket: String? = nil,
    flag: UInt = 0,
    encoding: String = "utf8mb4",
    optionsGroupName: String = "vapor"
)
```

### Connection

Use the created database to make a connection.

```
let conn = try mysql.makeConnection()
```

### Select

```swift
let results = try conn.execute("SELECT @@version")
```

#### Result

Accessing the result is made easy with [Node](http://github.com/vapor/node), [PathIndexable](http://github.com/vapor/path-indexable), and [Polymorphic](http://github.com/vapor/polymorphic).

```swift
if let version = results[0, "@@version"]?.string {
    print("Version is \(version).")    
} else {
    print("Result did not contain a version.")
}
```

`0` grabs the first result from the results array, and then `"@@version"` indexes into the first object.

Finally `.string` attempts to convert the result into a string, returning `nil` if that is not possible.

### Prepared Statement

The second parameter to `execute()` is an array of `Node`s.

```swift
let results = try conn.execute("SELECT * FROM users WHERE age >= ?", [21])
```

### Transaction

If any one of the executions fails inside of a `transaction` block, all changes will be reverted.

```swift
try conn.transaction {
    try conn.execute("UPDATE ...")
    try conn.execute("UPDATE ...")
    try conn.execute("UPDATE ...")
}
```

## 🚀 Building

### macOS

Install MySQL

```shell
brew install mysql
brew link mysql
mysql.server start
```

Use `vapor build` or manually link MySQL during `swift build` with

```swift
swift build -Xswiftc -I/usr/local/include/mysql -Xlinker -L/usr/local/lib
```

`-I` tells the compiler where to find the MySQL header files, and `-L` tells the linker where to find the library. This is required to compile and run on macOS.

### Linux

Install MySQL

```shell
sudo apt-get update
sudo apt-get install -y mysql-server libmysqlclient-dev
sudo mysql_install_db
sudo service mysql start
```

Use `vapor build`. `swift build` should also work normally.

## 📖 Documentation

Visit the Vapor web framework's [documentation](http://docs.vapor.codes) for instructions on how to use this package.

## 💧 Community

Join the welcoming community of fellow Vapor developers in [slack](http://vapor.team).

## 🔧 Compatibility

This package has been tested on macOS and Ubuntu.
