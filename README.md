# MySQL for Swift

![Swift](http://img.shields.io/badge/swift-3.0-brightgreen.svg)
![Swift](https://camo.githubusercontent.com/0727f3687a1e263cac101c5387df41048641339c/68747470733a2f2f696d672e736869656c64732e696f2f62616467652f53776966742d332e302d6f72616e67652e7376673f7374796c653d666c6174)
[![Build Status](https://travis-ci.org/vapor/mysql.svg?branch=master)](https://travis-ci.org/vapor/mysql)

This wrapper uses the latest MySQL fetch API to enable performant prepared statements and output bindings. Data is sent to and received from the MySQL server in its native data type without converting to and from strings.

The Swift wrappers around the MySQL's C structs and pointers automatically manage closing connections and deallocating memeory. Additionally, the MySQL library API is used to perform thread safe, performant queries to the database.

~40 assertions tested on Ubuntu 14.04 and macOS 10.11 on every push.

## 📖 Documentation

Visit the Vapor web framework's [documentation](http://docs.vapor.codes) for instructions on how to use this package.

## 💧 Community

Join the welcoming community of fellow Vapor developers in [slack](http://vapor.team).

## 🔧 Compatibility

This package has been tested on macOS and Ubuntu.
