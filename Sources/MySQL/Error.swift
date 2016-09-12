/**
    A list of all Error messages that
    can be thrown from calls to `Database`.

    All Error objects contain a String which
    contains MySQL's last error message.
*/
public enum Error: Swift.Error {
    case serverInit
    case connection(String)
    case inputBind(String)
    case outputBind(String)
    case fetchFields(String)
    case prepare(String)
    case statement(String)
    case execute(String)
}
