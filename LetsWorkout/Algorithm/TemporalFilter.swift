import Foundation

final class TemporalFilter {
    private let alpha: Float
    private var lastValue: Float?

    init(alpha: Float = 0.3) {
        self.alpha = alpha
    }

    func filter(_ value: Float) -> Float {
        guard let last = lastValue else {
            lastValue = value
            return value
        }

        let filtered = alpha * value + (1 - alpha) * last
        lastValue = filtered
        return filtered
    }

    func reset() {
        lastValue = nil
    }
}
