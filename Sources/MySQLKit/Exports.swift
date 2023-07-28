#if swift(>=5.8)

@_documentation(visibility: internal) @_exported import MySQLNIO
@_documentation(visibility: internal) @_exported import AsyncKit
@_documentation(visibility: internal) @_exported import SQLKit
@_documentation(visibility: internal) @_exported import struct Foundation.URL
@_documentation(visibility: internal) @_exported import struct Foundation.Data
@_documentation(visibility: internal) @_exported import struct NIOSSL.TLSConfiguration

#else

@_exported import MySQLNIO
@_exported import AsyncKit
@_exported import SQLKit
@_exported import struct Foundation.URL
@_exported import struct Foundation.Data
@_exported import struct NIOSSL.TLSConfiguration

#endif
