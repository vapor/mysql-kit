import Foundation
import Async
import Bits

/// Any MySQL packet
internal final class Packet: ExpressibleByArrayLiteral {
    /// Keeps track of the mutability of the buffer so it can be deallocated
    enum Buffer {
        case mutable(MutableByteBuffer)
        case immutable(ByteBuffer)
    }
    
    // Maximum payload size
    static let maxPayloadSize: Int = 16_777_216
    
    /// The sequence ID is incremented per message
    /// This client doesn't use this
    /// The max packet size is 2^24-1 bytes, so the packet fragmenting is hardly used.
    /// There are cases like bigdata bulk loading, big blob fetch etc when the SERVER will use it,
    /// therefore later we need to address this
    
    var sequenceId: UInt8 {
        get {
            return containsPacketSize ? buffer[3] : buffer[0]
        }
        set {
            if case .mutable(let buffer) = _buffer {
                if containsPacketSize {
                    buffer[3] = newValue
                } else {
                    buffer[0] = newValue
                }
            } else {
                fatalError("Trying to set a sequenceID on a server packet")
            }
        }
    }
    
    var containsPacketSize: Bool
    
    /// The payload contains the packet's data
    var payload: ByteBuffer {
        let buffer = self.buffer
        
        if containsPacketSize {
            // size (UInt24) + sequenceId + payload
            return ByteBuffer(start: buffer.baseAddress?.advanced(by: 4), count: buffer.count &- 4)
        } else {
            // sequenceId + payload
            return ByteBuffer(start: buffer.baseAddress?.advanced(by: 1), count: buffer.count &- 1)
        }
    }
    
    /// The payload contains the packet's data
    var buffer: ByteBuffer {
        switch _buffer {
        case .immutable(let buffer):
            return buffer
        case .mutable(let buffer):
            return ByteBuffer(start: buffer.baseAddress, count: buffer.count)
        }
    }
    
    var _buffer: Buffer
    
    /// Creates a new packet
    init(payload: ByteBuffer, containsPacketSize: Bool = false) {
        self._buffer = .immutable(payload)
        self.containsPacketSize = containsPacketSize
    }
    
    /// Creates a new packet
    init(payload: MutableByteBuffer, containsPacketSize: Bool = false) {
        self._buffer = .mutable(payload)
        self.containsPacketSize = containsPacketSize
    }
    
    deinit {
        if case .mutable(let buffer) = _buffer {
            // Deallocates the MySQL buffer
            buffer.baseAddress?.deallocate()
        }
    }
    
    convenience init(arrayLiteral elements: UInt8...) {
        let pointer = MutableBytesPointer.allocate(capacity: 4 &+ elements.count)
        
        let packetSizeBytes = [
            UInt8((elements.count) & 0xff),
            UInt8((elements.count >> 8) & 0xff),
            UInt8((elements.count >> 16) & 0xff),
        ]
        var sequenceId = UInt8(0)

        memcpy(pointer, packetSizeBytes, 3)
       
        memcpy(pointer.advanced(by: 3), &sequenceId, 1)
        
        memcpy(pointer.advanced(by: 1), elements, elements.count)
        
        self.init(payload: MutableByteBuffer(start: pointer, count: 4 &+ elements.count), containsPacketSize: true)
    }
    
    convenience init(data: [UInt8]) {
        let pointer = MutableBytesPointer.allocate(capacity: 4 &+ data.count)
        
        let packetSizeBytes = [
            UInt8((data.count) & 0xff),
            UInt8((data.count >> 8) & 0xff),
            UInt8((data.count >> 16) & 0xff),
            ]
        var  sequenceId = UInt8(0)
        memcpy(pointer, packetSizeBytes, 3)
        
        memcpy(pointer.advanced(by: 3), &sequenceId, 1)
        
        memcpy(pointer.advanced(by: 1), data, data.count)
        
        self.init(payload: MutableByteBuffer(start: pointer, count: 4 &+ data.count), containsPacketSize: true)
    }
    
    convenience init(data: Data) {
        let pointer = MutableBytesPointer.allocate(capacity: 4 &+ data.count)
        
        let packetSizeBytes = [
            UInt8((data.count) & 0xff),
            UInt8((data.count >> 8) & 0xff),
            UInt8((data.count >> 16) & 0xff),
        ]
        var sequenceId = UInt8(0)
        
        memcpy(pointer, packetSizeBytes, 3)
        
        memcpy(pointer.advanced(by: 3), &sequenceId, 1)
        
        data.withByteBuffer { buffer in
            _ = memcpy(pointer.advanced(by: 1), buffer.baseAddress!, data.count)
        }
        
        self.init(payload: MutableByteBuffer(start: pointer, count: 4 &+ data.count), containsPacketSize: true)
    }
}
