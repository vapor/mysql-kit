import Core
import TCP
import Dispatch

final class Connection {
    let socket: Socket
    let queue: DispatchQueue
    let buffer: MutableByteBuffer
    let parser: PacketParser
    var handshake: Handshake?
    var source: DispatchSourceRead
    
    public var initialized: Bool {
        return self.handshake != nil
    }
    
    init(hostname: String, port: UInt16 = 3306, queue: DispatchQueue) throws {
        let socket = try Socket()
        
        let bufferSize = Int(UInt16.max)
        
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        let buffer = MutableByteBuffer(start: pointer, count: bufferSize)
        
        try socket.connect(hostname: hostname, port: port)
        
        let parser = PacketParser()
        
        let source = socket.onReadable(queue: queue) {
            do {
                let usedBufferSize = try socket.read(max: bufferSize, into: buffer)
                
                // Reuse existing pointer to data
                let newBuffer = MutableByteBuffer(start: pointer, count: usedBufferSize)
                
                parser.inputStream(newBuffer)
            } catch {
                socket.close()
            }
        }
        
        self.parser = parser
        self.socket = socket
        self.queue = queue
        self.buffer = buffer
        self.source = source
        
        self.parser.consume(self.handlePacket)
    }
    
    func handlePacket(_ packet: Packet) {
        guard self.handshake != nil else {
            do {
                self.handshake = try packet.parseHandshake()
            } catch {
                self.socket.close()
            }
            
            return
        }
        
        
    }
}
