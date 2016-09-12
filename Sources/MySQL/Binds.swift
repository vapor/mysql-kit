#if os(Linux)
    #if MARIADB
        import CMariaDBLinux
    #else
        import CMySQLLinux
    #endif
#else
    import CMySQLMac
#endif

/**
    Wraps a pointer to an array of bindings
    to ensure proper freeing of allocated memory.
*/
public final class Binds {
    public typealias CBinds = UnsafeMutablePointer<Bind.CBind>

    public let cBinds: CBinds
    public let binds: [Bind]

    /** 
        Creastes an array of input bindings
        from values.
    */
    public convenience init(_ values: [NodeRepresentable]) throws {
        let binds = try values.map { try $0.makeNode().bind }
        self.init(binds)
    }


    /**
        Creates an array of output bindings
        from expected Fields.
    */
    public convenience init(_ fields: Fields) {
        var binds: [Bind] = []

        for field in fields.fields {
            let bind = Bind(field)
            binds.append(bind)
        }

        self.init(binds)
    }

    /**
        Initializes from an array of Bindings.
    */
    public init(_ binds: [Bind]) {
        let cBinds = CBinds.allocate(capacity: binds.count)

        for (i, bind) in binds.enumerated() {
            cBinds[i] = bind.cBind
        }

        self.cBinds = cBinds
        self.binds = binds
    }


    /**
        Subscripts into the underlying Bindings array.
    */
    public subscript(int: Int) -> Bind {
        return binds[int]
    }

    deinit {
        cBinds.deinitialize()
        cBinds.deallocate(capacity: binds.count)
    }

}
