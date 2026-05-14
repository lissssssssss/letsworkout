import ReplayKit

class SampleHandler: RPBroadcastSampleHandler {
    private let memoryWriter = SharedMemoryWriter()
    private let frameScaler = FrameScaler()
    private var frameCount: UInt64 = 0
    private let targetFPS: Int = 30
    private var lastFrameTime: CFTimeInterval = 0

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        do {
            try memoryWriter.setup()
        } catch {
            finishBroadcastWithError(NSError(domain: "com.letsworkout.broadcast", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "共享内存初始化失败"
            ]))
        }
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {
        memoryWriter.teardown()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }

        let now = CACurrentMediaTime()
        let minInterval = 1.0 / Double(targetFPS)
        guard (now - lastFrameTime) >= minInterval else { return }
        lastFrameTime = now

        guard let scaled = frameScaler.scaleFrame(sampleBuffer) else { return }

        memoryWriter.writeFrame(
            pixelData: scaled.pointer,
            size: scaled.size,
            width: AppConstants.frameWidth,
            height: AppConstants.frameHeight,
            bytesPerRow: scaled.bytesPerRow
        )

        frameCount += 1
    }
}
