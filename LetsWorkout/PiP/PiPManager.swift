import AVKit
import AVFoundation
import UIKit

protocol PiPManagerDelegate: AnyObject {
    func pipManagerDidStart(_ manager: PiPManager)
    func pipManagerDidStop(_ manager: PiPManager)
    func pipManagerRestoreUserInterface(_ manager: PiPManager)
}

final class PiPManager: NSObject {
    weak var delegate: PiPManagerDelegate?

    private var pipController: AVPictureInPictureController?
    private let displayLayer = AVSampleBufferDisplayLayer()
    private(set) var renderer: PiPRenderer?
    private var pipPossibleObservation: NSKeyValueObservation?

    var isActive: Bool { pipController?.isPictureInPictureActive ?? false }

    func setup() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }

        displayLayer.videoGravity = .resizeAspectFill

        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )

        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true

        renderer = PiPRenderer(displayLayer: displayLayer)

        pipPossibleObservation = pipController?.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] _, change in
            if change.newValue == true {
                self?.startIfNeeded()
            }
        }
    }

    func start() {
        guard let controller = pipController, !controller.isPictureInPictureActive else { return }
        controller.startPictureInPicture()
    }

    func stop() {
        pipController?.stopPictureInPicture()
    }

    private func startIfNeeded() {
        guard let controller = pipController,
              controller.isPictureInPicturePossible,
              !controller.isPictureInPictureActive else { return }
        controller.startPictureInPicture()
    }
}

extension PiPManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {}

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        delegate?.pipManagerDidStart(self)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        delegate?.pipManagerDidStop(self)
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        delegate?.pipManagerRestoreUserInterface(self)
        completionHandler(true)
    }
}

extension PiPManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    setPlaying playing: Bool) {}

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    skipByInterval skipInterval: CMTime) async {}
}
