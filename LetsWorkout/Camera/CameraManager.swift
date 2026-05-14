import AVFoundation
import CoreVideo

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutput frame: CameraFrame)
    func cameraManagerWasInterrupted(_ manager: CameraManager)
    func cameraManagerInterruptionEnded(_ manager: CameraManager)
}

final class CameraManager: NSObject {
    weak var delegate: CameraManagerDelegate?

    private let session = AVCaptureSession()
    private let outputQueue = DispatchQueue(label: "com.letsworkout.camera", qos: .userInteractive)
    private var isRunning = false

    var isSessionRunning: Bool { session.isRunning }

    func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .vga640x480

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CameraError.deviceNotFound
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: outputQueue)

        guard session.canAddOutput(output) else { throw CameraError.cannotAddOutput }
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            connection.videoOrientation = .portrait
            connection.isVideoMirrored = true
        }

        configureFrameRate(device: device, fps: 30)

        NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted),
                                               name: .AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded),
                                               name: .AVCaptureSessionInterruptionEnded, object: session)
    }

    func start() {
        guard !session.isRunning else { return }
        outputQueue.async { [weak self] in
            self?.session.startRunning()
            self?.isRunning = true
        }
    }

    func stop() {
        guard session.isRunning else { return }
        outputQueue.async { [weak self] in
            self?.session.stopRunning()
            self?.isRunning = false
        }
    }

    private func configureFrameRate(device: AVCaptureDevice, fps: Int) {
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
            device.unlockForConfiguration()
        } catch {}
    }

    @objc private func sessionWasInterrupted(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.cameraManagerWasInterrupted(self)
        }
    }

    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.cameraManagerInterruptionEnded(self)
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let frame = CameraFrame(pixelBuffer: pixelBuffer, timestamp: timestamp, isMirrored: true)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.cameraManager(self, didOutput: frame)
        }
    }
}

enum CameraError: Error {
    case deviceNotFound
    case cannotAddInput
    case cannotAddOutput
}
