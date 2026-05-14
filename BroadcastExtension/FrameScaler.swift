import Accelerate
import CoreMedia
import CoreVideo

final class FrameScaler {
    private let targetWidth = Int(AppConstants.frameWidth)
    private let targetHeight = Int(AppConstants.frameHeight)
    private var outputBuffer: UnsafeMutableRawPointer?
    private var outputBufferSize: Int = 0

    init() {
        outputBufferSize = targetWidth * targetHeight * 4
        outputBuffer = UnsafeMutableRawPointer.allocate(byteCount: outputBufferSize, alignment: 16)
    }

    func scaleFrame(_ sampleBuffer: CMSampleBuffer) -> (pointer: UnsafeRawPointer, size: Int, bytesPerRow: UInt32)? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let srcBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let srcWidth = CVPixelBufferGetWidth(pixelBuffer)
        let srcHeight = CVPixelBufferGetHeight(pixelBuffer)
        let srcBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        var srcBuffer = vImage_Buffer(
            data: srcBaseAddress,
            height: vImagePixelCount(srcHeight),
            width: vImagePixelCount(srcWidth),
            rowBytes: srcBytesPerRow
        )

        let dstBytesPerRow = targetWidth * 4
        var dstBuffer = vImage_Buffer(
            data: outputBuffer!,
            height: vImagePixelCount(targetHeight),
            width: vImagePixelCount(targetWidth),
            rowBytes: dstBytesPerRow
        )

        let error = vImageScale_ARGB8888(&srcBuffer, &dstBuffer, nil, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }

        return (UnsafeRawPointer(outputBuffer!), outputBufferSize, UInt32(dstBytesPerRow))
    }

    deinit {
        outputBuffer?.deallocate()
    }
}
