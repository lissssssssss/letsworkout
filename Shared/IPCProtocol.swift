import Foundation

struct SharedBufferHeader {
    var writeIndex: UInt32
    var readIndex: UInt32
    var extensionAlive: UInt32 // 1 = alive, 0 = dead
    var heartbeatTimestamp: UInt64
}

struct FrameHeader {
    var sequence: UInt64
    var timestamp: UInt64
    var width: UInt32
    var height: UInt32
    var bytesPerRow: UInt32
    var dataSize: UInt32
    var isValid: UInt32 // 1 = valid frame, 0 = empty
    var _padding: UInt32
}

struct FrameSlot {
    static let headerSize = MemoryLayout<FrameHeader>.size
    static let dataSize = AppConstants.frameSize
    static let slotSize = headerSize + dataSize
}

enum IPCError: Error {
    case sharedMemoryCreateFailed
    case sharedMemoryMapFailed
    case bufferFull
    case noNewFrame
    case extensionDead
}
