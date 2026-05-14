import Foundation
import CoreVideo

enum InputMode {
    case live          // 真机：前置摄像头（用户）+ 本地参考视频（主播）
    case simulated     // 模拟器：两路视频文件模拟
}

final class SessionCoordinator: ObservableObject {
    @Published var session = WorkoutSession()
    @Published var inputMode: InputMode

    // Input sources
    private var cameraManager: CameraManager?
    private var referenceVideoReader = VideoFrameReader()
    private var simulatedCamera: SimulatedCamera?

    // AI & Algorithm
    private let poseScheduler: DualPoseScheduler
    private let normalizer = SkeletonNormalizer()
    private let mirrorCorrector = MirrorCorrector()
    private let angleCalculator = JointAngleCalculator()
    private let dtwMatcher = DTWMatcher()
    private let scorer = SimilarityScorer()
    private let temporalFilter = TemporalFilter()
    private let voiceFeedback = VoiceFeedback()

    // PiP (only on real device)
    private var pipManager: PiPManager?

    // State
    private var latestScreenPose: PoseResult?
    private var latestCameraPose: PoseResult?
    private var noPoseFrameCount = 0
    private let noPoseThreshold = 150

    init() {
        #if targetEnvironment(simulator)
        self.inputMode = .simulated
        #else
        self.inputMode = .live
        #endif

        let mode: InferenceMode = DeviceCapability.current.supportsParallelInference ? .parallel : .interleaved
        poseScheduler = DualPoseScheduler(mode: mode)
        poseScheduler.delegate = self
    }

    // MARK: - Start / Stop

    func startWorkout(referenceVideoURL: URL?) {
        dtwMatcher.reset()
        temporalFilter.reset()
        noPoseFrameCount = 0
        latestScreenPose = nil
        latestCameraPose = nil

        switch inputMode {
        case .live:
            startLiveMode(referenceVideoURL: referenceVideoURL)
        case .simulated:
            startSimulatedMode(referenceVideoURL: referenceVideoURL)
        }

        session.start()
    }

    func stopWorkout() {
        cameraManager?.stop()
        referenceVideoReader.stop()
        simulatedCamera?.stop()
        pipManager?.stop()
        voiceFeedback.stop()
        session.finish()
    }

    func pauseWorkout(reason: SessionState.PauseReason) {
        session.pause(reason: reason)
        referenceVideoReader.pause()
    }

    func resumeWorkout() {
        session.resume()
        referenceVideoReader.resume()
    }

    // MARK: - Live Mode (Real Device)

    private func startLiveMode(referenceVideoURL: URL?) {
        // Camera for user
        let camera = CameraManager()
        do {
            try camera.configure()
            camera.delegate = self
            camera.start()
            self.cameraManager = camera
        } catch {
            session.pause(reason: .cameraInterrupted)
            return
        }

        // Reference video for "instructor"
        if let url = referenceVideoURL {
            referenceVideoReader.delegate = self
            referenceVideoReader.loadVideo(url: url)
            referenceVideoReader.start()
        } else if let bundleURL = Bundle.main.url(forResource: "reference_workout", withExtension: "mp4") {
            referenceVideoReader.delegate = self
            referenceVideoReader.loadVideo(url: bundleURL)
            referenceVideoReader.start()
        }

        // PiP
        pipManager = PiPManager()
        pipManager?.delegate = self
        pipManager?.setup()
        pipManager?.start()
    }

    // MARK: - Simulated Mode (Simulator)

    private func startSimulatedMode(referenceVideoURL: URL?) {
        // Reference video
        if let url = referenceVideoURL {
            referenceVideoReader.delegate = self
            referenceVideoReader.loadVideo(url: url)
            referenceVideoReader.start()
        } else if let bundleURL = Bundle.main.url(forResource: "reference_workout", withExtension: "mp4") {
            referenceVideoReader.delegate = self
            referenceVideoReader.loadVideo(url: bundleURL)
            referenceVideoReader.start()
        }

        // Simulated user camera (from video file)
        let sim = SimulatedCamera()
        sim.delegate = self
        if let userURL = Bundle.main.url(forResource: "user_workout", withExtension: "mp4") {
            sim.start(mode: .video(userURL))
        } else if let placeholderImage = createPlaceholderImage() {
            sim.start(mode: .staticImage(placeholderImage))
        }
        self.simulatedCamera = sim
    }

    // MARK: - Core Processing Pipeline

    private func processComparison() {
        guard case .active = session.state else { return }
        guard let screenPose = latestScreenPose, let cameraPose = latestCameraPose else { return }

        guard screenPose.isValid, cameraPose.isValid else {
            handleNoPose()
            return
        }

        noPoseFrameCount = 0

        guard let screenSkeleton = normalizer.normalize(screenPose),
              let cameraSkeleton = normalizer.normalize(cameraPose) else { return }

        let isMirrored = (inputMode == .live)
        let correctedCamera = mirrorCorrector.correct(cameraSkeleton, isMirrored: isMirrored)

        let screenAngles = angleCalculator.calculate(from: screenSkeleton, pose: screenPose)
        let cameraAngles = angleCalculator.calculate(from: correctedCamera, pose: cameraPose)

        let screenAngleValues = screenAngles.filter { $0.isValid }.map { $0.angle }
        let cameraAngleValues = cameraAngles.filter { $0.isValid }.map { $0.angle }
        dtwMatcher.addReferenceFrame(angles: screenAngleValues)
        dtwMatcher.addQueryFrame(angles: cameraAngleValues)

        let dtwDistance = dtwMatcher.computeDistance()

        let result = scorer.computeScore(
            referenceAngles: screenAngles,
            queryAngles: cameraAngles,
            referenceSkeleton: screenSkeleton,
            querySkeleton: correctedCamera,
            dtwDistance: dtwDistance
        )

        let smoothedScore = temporalFilter.filter(result.score)
        let smoothedResult = ScoreResult(score: smoothedScore, feedback: result.feedback, jointErrors: result.jointErrors)

        session.updateScore(smoothedResult)

        if let feedback = smoothedResult.feedback {
            voiceFeedback.speak(feedback)
        }
    }

    private func handleNoPose() {
        noPoseFrameCount += 1
        if noPoseFrameCount >= noPoseThreshold {
            session.pause(reason: .noPoseDetected)
        }
    }

    private func createPlaceholderImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 480, height: 640))
        return renderer.image { ctx in
            UIColor.darkGray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 480, height: 640))
        }
    }
}

// MARK: - CameraManagerDelegate

extension SessionCoordinator: CameraManagerDelegate {
    func cameraManager(_ manager: CameraManager, didOutput frame: CameraFrame) {
        guard case .active = session.state else { return }
        poseScheduler.processCameraFrame(frame.pixelBuffer, timestamp: frame.timestamp)
        pipManager?.renderer?.renderFrame(frame.pixelBuffer, score: session.currentScore)
    }

    func cameraManagerWasInterrupted(_ manager: CameraManager) {
        pauseWorkout(reason: .cameraInterrupted)
    }

    func cameraManagerInterruptionEnded(_ manager: CameraManager) {
        resumeWorkout()
    }
}

// MARK: - VideoFrameReaderDelegate (Reference video)

extension SessionCoordinator: VideoFrameReaderDelegate {
    func videoFrameReader(_ reader: VideoFrameReader, didOutput pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        guard case .active = session.state else { return }
        poseScheduler.processScreenFrame(pixelBuffer, timestamp: timestamp)
    }

    func videoFrameReaderDidFinish(_ reader: VideoFrameReader) {
        // Video loops by default, this only fires if loop is disabled
    }
}

// MARK: - SimulatedCameraDelegate (Simulator user)

extension SessionCoordinator: SimulatedCameraDelegate {
    func simulatedCamera(_ camera: SimulatedCamera, didOutput pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        guard case .active = session.state else { return }
        poseScheduler.processCameraFrame(pixelBuffer, timestamp: timestamp)
    }
}

// MARK: - DualPoseSchedulerDelegate

extension SessionCoordinator: DualPoseSchedulerDelegate {
    func scheduler(_ scheduler: DualPoseScheduler, didProduceScreenPose pose: PoseResult) {
        latestScreenPose = pose
        processComparison()
    }

    func scheduler(_ scheduler: DualPoseScheduler, didProduceCameraPose pose: PoseResult) {
        latestCameraPose = pose
        processComparison()
    }
}

// MARK: - PiPManagerDelegate

extension SessionCoordinator: PiPManagerDelegate {
    func pipManagerDidStart(_ manager: PiPManager) {}

    func pipManagerDidStop(_ manager: PiPManager) {
        pauseWorkout(reason: .pipClosed)
    }

    func pipManagerRestoreUserInterface(_ manager: PiPManager) {
        resumeWorkout()
    }
}
