import Foundation
import os.lock

final class RingBuffer {
    private let capacity: Int
    private let basePointer: UnsafeMutableRawPointer

    private var header: UnsafeMutablePointer<SharedBufferHeader> {
        basePointer.bindMemory(to: SharedBufferHeader.self, capacity: 1)
    }

    init(basePointer: UnsafeMutableRawPointer, capacity: Int) {
        self.basePointer = basePointer
        self.capacity = capacity
    }

    // MARK: - Writer (Extension side)

    func writeFrame(data: UnsafeRawPointer, size: Int, width: UInt32, height: UInt32, bytesPerRow: UInt32, timestamp: UInt64) {
        let currentWrite = Int(header.pointee.writeIndex)
        let slotIndex = currentWrite % capacity
        let slotPointer = slotPointerAt(index: slotIndex)

        let frameHeader = slotPointer.bindMemory(to: FrameHeader.self, capacity: 1)
        frameHeader.pointee.sequence = UInt64(currentWrite)
        frameHeader.pointee.timestamp = timestamp
        frameHeader.pointee.width = width
        frameHeader.pointee.height = height
        frameHeader.pointee.bytesPerRow = bytesPerRow
        frameHeader.pointee.dataSize = UInt32(size)
        frameHeader.pointee.isValid = 0

        let dataPointer = slotPointer.advanced(by: FrameSlot.headerSize)
        memcpy(dataPointer, data, min(size, FrameSlot.dataSize))

        OSMemoryBarrier()
        frameHeader.pointee.isValid = 1

        OSAtomicIncrement32(UnsafeMutablePointer<Int32>(OpaquePointer(UnsafeMutablePointer(&header.pointee.writeIndex))))
    }

    // MARK: - Reader (Main App side)

    func readLatestFrame() -> (data: UnsafeRawPointer, header: FrameHeader)? {
        let currentWrite = Int(header.pointee.writeIndex)
        guard currentWrite > 0 else { return nil }

        let latestSlotIndex = (currentWrite - 1) % capacity
        let slotPointer = slotPointerAt(index: latestSlotIndex)

        let frameHeader = slotPointer.bindMemory(to: FrameHeader.self, capacity: 1)

        OSMemoryBarrier()
        guard frameHeader.pointee.isValid == 1 else { return nil }

        let dataPointer = UnsafeRawPointer(slotPointer.advanced(by: FrameSlot.headerSize))
        return (dataPointer, frameHeader.pointee)
    }

    func currentWriteIndex() -> UInt32 {
        return header.pointee.writeIndex
    }

    // MARK: - Heartbeat

    func updateHeartbeat() {
        header.pointee.heartbeatTimestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        header.pointee.extensionAlive = 1
    }

    func isExtensionAlive(timeoutMs: UInt64 = 2000) -> Bool {
        guard header.pointee.extensionAlive == 1 else { return false }
        let now = UInt64(Date().timeIntervalSince1970 * 1000)
        return (now - header.pointee.heartbeatTimestamp) < timeoutMs
    }

    // MARK: - Private

    private func slotPointerAt(index: Int) -> UnsafeMutableRawPointer {
        let offset = MemoryLayout<SharedBufferHeader>.size + (index * FrameSlot.slotSize)
        return basePointer.advanced(by: offset)
    }
}
