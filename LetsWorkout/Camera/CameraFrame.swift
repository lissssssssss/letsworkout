import Foundation
import CoreVideo

struct CameraFrame {
    let pixelBuffer: CVPixelBuffer
    let timestamp: TimeInterval
    let isMirrored: Bool

    var width: Int { CVPixelBufferGetWidth(pixelBuffer) }
    var height: Int { CVPixelBufferGetHeight(pixelBuffer) }
}
