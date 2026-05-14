import AVFoundation
import CoreVideo
import UIKit

protocol SimulatedCameraDelegate: AnyObject {
    func simulatedCamera(_ camera: SimulatedCamera, didOutput pixelBuffer: CVPixelBuffer, timestamp: TimeInterval)
}

final class SimulatedCamera {
    weak var delegate: SimulatedCameraDelegate?

    private var videoReader: VideoFrameReader?
    private var displayLink: CADisplayLink?
    private var staticImage: CVPixelBuffer?
    private var frameCount: UInt64 = 0

    enum Mode {
        case video(URL)
        case staticImage(UIImage)
    }

    func start(mode: Mode) {
        switch mode {
        case .video(let url):
            let reader = VideoFrameReader()
            reader.delegate = self
            reader.loadVideo(url: url)
            reader.start()
            self.videoReader = reader

        case .staticImage(let image):
            staticImage = pixelBuffer(from: image)
            startStaticFrameLoop()
        }
    }

    func stop() {
        videoReader?.stop()
        videoReader = nil
        displayLink?.invalidate()
        displayLink = nil
    }

    private func startStaticFrameLoop() {
        displayLink = CADisplayLink(target: self, selector: #selector(emitStaticFrame))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func emitStaticFrame() {
        guard let pb = staticImage else { return }
        frameCount += 1
        let timestamp = CACurrentMediaTime()
        delegate?.simulatedCamera(self, didOutput: pb, timestamp: timestamp)
    }

    private func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }

        let width = 480
        let height = 640
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &pb)
        guard let pixelBuffer = pb else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        return pixelBuffer
    }
}

extension SimulatedCamera: VideoFrameReaderDelegate {
    func videoFrameReader(_ reader: VideoFrameReader, didOutput pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        delegate?.simulatedCamera(self, didOutput: pixelBuffer, timestamp: timestamp)
    }

    func videoFrameReaderDidFinish(_ reader: VideoFrameReader) {}
}
