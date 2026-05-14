import AVFoundation
import CoreVideo

protocol VideoFrameReaderDelegate: AnyObject {
    func videoFrameReader(_ reader: VideoFrameReader, didOutput pixelBuffer: CVPixelBuffer, timestamp: TimeInterval)
    func videoFrameReaderDidFinish(_ reader: VideoFrameReader)
}

final class VideoFrameReader {
    weak var delegate: VideoFrameReaderDelegate?

    private var asset: AVAsset?
    private var reader: AVAssetReader?
    private var videoOutput: AVAssetReaderTrackOutput?
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var videoStartTime: CMTime = .zero
    private let outputQueue = DispatchQueue(label: "com.letsworkout.videoreader")

    private var isPlaying = false
    private var shouldLoop = true

    var isReady: Bool { asset != nil }

    func loadVideo(url: URL) {
        asset = AVAsset(url: url)
        prepareReader()
    }

    func loadBundleVideo(named name: String, extension ext: String = "mp4") {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("[VideoFrameReader] Bundle video not found: \(name).\(ext)")
            return
        }
        loadVideo(url: url)
    }

    func start() {
        guard !isPlaying else { return }
        isPlaying = true

        if reader == nil || reader?.status == .completed {
            prepareReader()
        }

        startTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        isPlaying = false
        displayLink?.invalidate()
        displayLink = nil
        reader?.cancelReading()
        reader = nil
    }

    func pause() {
        displayLink?.isPaused = true
    }

    func resume() {
        displayLink?.isPaused = false
    }

    // MARK: - Private

    private func prepareReader() {
        guard let asset = asset,
              let videoTrack = asset.tracks(withMediaType: .video).first else { return }

        do {
            let reader = try AVAssetReader(asset: asset)
            let outputSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
            output.alwaysCopiesSampleData = false

            if reader.canAdd(output) {
                reader.add(output)
            }

            reader.startReading()
            self.reader = reader
            self.videoOutput = output
            self.videoStartTime = videoTrack.timeRange.start
        } catch {
            print("[VideoFrameReader] Failed to create reader: \(error)")
        }
    }

    @objc private func tick() {
        outputQueue.async { [weak self] in
            self?.readNextFrame()
        }
    }

    private func readNextFrame() {
        guard isPlaying, let output = videoOutput, let reader = reader else { return }

        if reader.status == .completed {
            if shouldLoop {
                prepareReader()
                startTime = CACurrentMediaTime()
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.videoFrameReaderDidFinish(self)
                }
                stop()
            }
            return
        }

        guard let sampleBuffer = output.copyNextSampleBuffer(),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestamp = CMTimeGetSeconds(pts)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.videoFrameReader(self, didOutput: pixelBuffer, timestamp: timestamp)
        }
    }

    deinit {
        stop()
    }
}
