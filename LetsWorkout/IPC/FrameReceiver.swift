import Foundation
import CoreVideo

protocol FrameReceiverDelegate: AnyObject {
    func frameReceiver(_ receiver: FrameReceiver, didReceiveFrame pixelBuffer: CVPixelBuffer, timestamp: TimeInterval)
    func frameReceiverExtensionDidDie(_ receiver: FrameReceiver)
}

final class FrameReceiver {
    weak var delegate: FrameReceiverDelegate?

    private let reader = SharedMemoryReader()
    private var pollTimer: DispatchSourceTimer?
    private var heartbeatTimer: DispatchSourceTimer?
    private var lastReadIndex: UInt32 = 0
    private let queue = DispatchQueue(label: "com.letsworkout.framereceiver", qos: .userInteractive)
    private var isRunning = false

    func start() throws {
        try reader.setup()
        isRunning = true
        startDarwinNotification()
        startPollTimer()
        startHeartbeatCheck()
    }

    func stop() {
        isRunning = false
        pollTimer?.cancel()
        pollTimer = nil
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        removeDarwinNotification()
        reader.teardown()
    }

    // MARK: - Darwin Notification

    private func startDarwinNotification() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = CFNotificationName(AppConstants.darwinNotifyName as CFString)

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let receiver = Unmanaged<FrameReceiver>.fromOpaque(observer).takeUnretainedValue()
                receiver.onNewFrameNotification()
            },
            name.rawValue,
            nil,
            .deliverImmediately
        )
    }

    private func removeDarwinNotification() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveObserver(center, Unmanaged.passUnretained(self).toOpaque(), nil, nil)
    }

    private func onNewFrameNotification() {
        queue.async { [weak self] in
            self?.tryReadFrame()
        }
    }

    // MARK: - Poll Timer (fallback)

    private func startPollTimer() {
        pollTimer = DispatchSource.makeTimerSource(queue: queue)
        pollTimer?.schedule(deadline: .now(), repeating: .milliseconds(IPCConstant.pollIntervalMs))
        pollTimer?.setEventHandler { [weak self] in
            self?.tryReadFrame()
        }
        pollTimer?.resume()
    }

    // MARK: - Heartbeat Check

    private func startHeartbeatCheck() {
        heartbeatTimer = DispatchSource.makeTimerSource(queue: queue)
        heartbeatTimer?.schedule(deadline: .now() + .milliseconds(IPCConstant.heartbeatCheckIntervalMs),
                                repeating: .milliseconds(IPCConstant.heartbeatCheckIntervalMs))
        heartbeatTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            if !self.reader.isExtensionAlive() {
                DispatchQueue.main.async {
                    self.delegate?.frameReceiverExtensionDidDie(self)
                }
            }
        }
        heartbeatTimer?.resume()
    }

    // MARK: - Frame Reading

    private func tryReadFrame() {
        guard isRunning else { return }

        let currentIndex = reader.currentWriteIndex()
        guard currentIndex > lastReadIndex else { return }
        lastReadIndex = currentIndex

        guard let (data, header) = reader.readLatestFrame() else { return }
        guard let pixelBuffer = createPixelBuffer(from: data, header: header) else { return }

        let timestamp = TimeInterval(header.timestamp) / 1000.0

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.frameReceiver(self, didReceiveFrame: pixelBuffer, timestamp: timestamp)
        }
    }

    private func createPixelBuffer(from data: Data, header: FrameHeader) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(header.width),
            Int(header.height),
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pb = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        guard let dest = CVPixelBufferGetBaseAddress(pb) else { return nil }
        data.withUnsafeBytes { srcPtr in
            memcpy(dest, srcPtr.baseAddress!, min(data.count, Int(header.bytesPerRow) * Int(header.height)))
        }

        return pb
    }
}
