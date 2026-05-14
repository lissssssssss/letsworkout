import Foundation

enum SessionState {
    case idle
    case preparing
    case active
    case paused(reason: PauseReason)
    case finished

    enum PauseReason {
        case extensionDied
        case cameraInterrupted
        case pipClosed
        case noPoseDetected
        case thermalThrottling
        case userManual
    }
}

final class WorkoutSession: ObservableObject {
    @Published var state: SessionState = .idle
    @Published var currentScore: Float = 0
    @Published var currentFeedback: String?
    @Published var duration: TimeInterval = 0
    @Published var averageScore: Float = 0

    private var startTime: Date?
    private var scores: [Float] = []
    private var timer: Timer?

    func start() {
        state = .active
        startTime = Date()
        scores = []
        startTimer()
    }

    func pause(reason: SessionState.PauseReason) {
        state = .paused(reason: reason)
        timer?.invalidate()
    }

    func resume() {
        state = .active
        startTimer()
    }

    func finish() {
        state = .finished
        timer?.invalidate()
    }

    func updateScore(_ result: ScoreResult) {
        currentScore = result.score
        currentFeedback = result.feedback
        scores.append(result.score)
        averageScore = scores.reduce(0, +) / Float(scores.count)
    }

    func reset() {
        state = .idle
        currentScore = 0
        currentFeedback = nil
        duration = 0
        averageScore = 0
        scores = []
        timer?.invalidate()
        startTime = nil
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            self.duration = Date().timeIntervalSince(start)
        }
    }
}
