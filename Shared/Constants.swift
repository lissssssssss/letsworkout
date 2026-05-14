import Foundation

enum AppConstants {
    static let appGroupID = "group.com.letsworkout.shared"
    static let sharedMemoryName = "com.letsworkout.framebuffer"
    static let darwinNotifyName = "com.letsworkout.newframe"
    static let heartbeatNotifyName = "com.letsworkout.heartbeat"

    static let frameWidth: UInt32 = 480
    static let frameHeight: UInt32 = 640
    static let bytesPerPixel: UInt32 = 4 // BGRA
    static let frameSize: Int = Int(frameWidth) * Int(frameHeight) * Int(bytesPerPixel)

    static let ringBufferCapacity: Int = 3
    static let totalSharedMemorySize: Int = MemoryLayout<SharedBufferHeader>.size + (FrameSlot.slotSize * ringBufferCapacity)
}
