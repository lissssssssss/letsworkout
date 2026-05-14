import AVFoundation
import CoreMedia
import CoreVideo

final class PiPRenderer {
    private let displayLayer: AVSampleBufferDisplayLayer
    private var formatDescription: CMFormatDescription?

    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
    }

    func renderFrame(_ pixelBuffer: CVPixelBuffer, score: Float?) {
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )

        if formatDescription == nil || !isFormatCompatible(pixelBuffer) {
            CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                formatDescriptionOut: &formatDescription
            )
        }

        guard let format = formatDescription else { return }

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )

        guard let buffer = sampleBuffer else { return }

        if let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true) as? [[CFString: Any]] {
            var dict = attachments.first ?? [:]
            dict[kCMSampleAttachmentKey_DisplayImmediately] = true
        }

        if displayLayer.status == .failed {
            displayLayer.flush()
        }

        displayLayer.enqueue(buffer)
    }

    private func isFormatCompatible(_ pixelBuffer: CVPixelBuffer) -> Bool {
        guard let format = formatDescription else { return false }
        let dimensions = CMVideoFormatDescriptionGetDimensions(format)
        return Int(dimensions.width) == CVPixelBufferGetWidth(pixelBuffer) &&
               Int(dimensions.height) == CVPixelBufferGetHeight(pixelBuffer)
    }
}
