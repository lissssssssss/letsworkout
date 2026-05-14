import Foundation

final class SharedMemoryWriter {
    private var fd: Int32 = -1
    private var mappedPointer: UnsafeMutableRawPointer?
    private var ringBuffer: RingBuffer?
    private let memorySize = AppConstants.totalSharedMemorySize

    var isReady: Bool { ringBuffer != nil }

    func setup() throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID) else {
            throw IPCError.sharedMemoryCreateFailed
        }

        let fileURL = containerURL.appendingPathComponent(AppConstants.sharedMemoryName)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: Data(count: memorySize))
        }

        fd = open(fileURL.path, O_RDWR)
        guard fd >= 0 else { throw IPCError.sharedMemoryCreateFailed }

        ftruncate(fd, off_t(memorySize))

        guard let ptr = mmap(nil, memorySize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0),
              ptr != MAP_FAILED else {
            close(fd)
            throw IPCError.sharedMemoryMapFailed
        }

        mappedPointer = ptr
        memset(ptr, 0, MemoryLayout<SharedBufferHeader>.size)
        ringBuffer = RingBuffer(basePointer: ptr, capacity: AppConstants.ringBufferCapacity)
    }

    func writeFrame(pixelData: UnsafeRawPointer, size: Int, width: UInt32, height: UInt32, bytesPerRow: UInt32) {
        guard let rb = ringBuffer else { return }

        let timestamp = UInt64(CACurrentMediaTime() * 1000)
        rb.writeFrame(data: pixelData, size: size, width: width, height: height, bytesPerRow: bytesPerRow, timestamp: timestamp)
        rb.updateHeartbeat()

        notifyNewFrame()
    }

    func teardown() {
        if let ptr = mappedPointer {
            munmap(ptr, memorySize)
        }
        if fd >= 0 {
            close(fd)
        }
        mappedPointer = nil
        ringBuffer = nil
        fd = -1
    }

    private func notifyNewFrame() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = CFNotificationName(AppConstants.darwinNotifyName as CFString)
        CFNotificationCenterPostNotification(center, name, nil, nil, true)
    }

    deinit {
        teardown()
    }
}
