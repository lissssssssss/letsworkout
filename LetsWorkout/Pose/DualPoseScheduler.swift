import CoreVideo
import Foundation

enum InferenceMode {
    case interleaved
    case parallel
}

protocol DualPoseSchedulerDelegate: AnyObject {
    func scheduler(_ scheduler: DualPoseScheduler, didProduceScreenPose pose: PoseResult)
    func scheduler(_ scheduler: DualPoseScheduler, didProduceCameraPose pose: PoseResult)
}

final class DualPoseScheduler {
    weak var delegate: DualPoseSchedulerDelegate?

    private let screenEstimator: PoseEstimatorProtocol
    private let cameraEstimator: PoseEstimatorProtocol
    private let inferenceQueue = DispatchQueue(label: "com.letsworkout.inference", qos: .userInteractive)

    private var mode: InferenceMode
    private var isScreenTurn = true
    private var isProcessing = false

    init(mode: InferenceMode = .interleaved) {
        self.mode = mode

        let useLiteModel = (mode == .interleaved)
        let modelName = useLiteModel ? "pose_landmarker_lite" : "pose_landmarker_full"
        let modelPath = Bundle.main.path(forResource: modelName, ofType: "task")

        self.screenEstimator = PoseEstimator(modelPath: modelPath, useGPU: true)
        self.cameraEstimator = PoseEstimator(modelPath: modelPath, useGPU: true)
    }

    func processScreenFrame(_ pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        inferenceQueue.async { [weak self] in
            guard let self = self else { return }

            switch self.mode {
            case .interleaved:
                guard self.isScreenTurn else { return }
                self.isScreenTurn = false
            case .parallel:
                break
            }

            guard let result = self.screenEstimator.detect(pixelBuffer: pixelBuffer, timestamp: timestamp, source: .screen) else { return }

            DispatchQueue.main.async {
                self.delegate?.scheduler(self, didProduceScreenPose: result)
            }
        }
    }

    func processCameraFrame(_ pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        inferenceQueue.async { [weak self] in
            guard let self = self else { return }

            switch self.mode {
            case .interleaved:
                guard !self.isScreenTurn else { return }
                self.isScreenTurn = true
            case .parallel:
                break
            }

            guard let result = self.cameraEstimator.detect(pixelBuffer: pixelBuffer, timestamp: timestamp, source: .camera) else { return }

            DispatchQueue.main.async {
                self.delegate?.scheduler(self, didProduceCameraPose: result)
            }
        }
    }

    func updateMode(_ newMode: InferenceMode) {
        inferenceQueue.async { [weak self] in
            self?.mode = newMode
        }
    }
}
