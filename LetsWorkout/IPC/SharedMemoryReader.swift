import Foundation

final class SharedMemoryReader {
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

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw IPCError.sharedMemoryCreateFailed
        }

        fd = open(fileURL.path, O_RDWR)
        guard fd >= 0 else { throw IPCError.sharedMemoryMapFailed }

        guard let ptr = mmap(nil, memorySize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0),
              ptr != MAP_FAILED else {
            close(fd)
            throw IPCError.sharedMemoryMapFailed
        }

        mappedPointer = ptr
        ringBuffer = RingBuffer(basePointer: ptr, capacity: AppConstants.ringBufferCapacity)
    }

    func readLatestFrame() -> (data: Data, header: FrameHeader)? {
        guard let rb = ringBuffer else { return nil }
        guard let (pointer, header) = rb.readLatestFrame() else { return nil }

        let data = Data(bytes: pointer, count: Int(header.dataSize))
        return (data, header)
    }

    func currentWriteIndex() -> UInt32 {
        return ringBuffer?.currentWriteIndex() ?? 0
    }

    func isExtensionAlive() -> Bool {
        return ringBuffer?.isExtensionAlive(timeoutMs: IPCConstant.extensionTimeoutMs) ?? false
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

    deinit {
        teardown()
    }
}
