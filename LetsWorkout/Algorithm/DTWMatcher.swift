import Foundation

final class DTWMatcher {
    private let windowSize: Int
    private let bandWidth: Int
    private var referenceBuffer: [[Float]] = []
    private var queryBuffer: [[Float]] = []
    private var isColdStart = true

    init(windowSize: Int = 60, bandWidth: Int = 10) {
        self.windowSize = windowSize
        self.bandWidth = bandWidth
    }

    func addReferenceFrame(angles: [Float]) {
        referenceBuffer.append(angles)
        if referenceBuffer.count > windowSize {
            referenceBuffer.removeFirst()
        }
        updateColdStartState()
    }

    func addQueryFrame(angles: [Float]) {
        queryBuffer.append(angles)
        if queryBuffer.count > windowSize {
            queryBuffer.removeFirst()
        }
        updateColdStartState()
    }

    var isInColdStart: Bool { isColdStart }

    func computeDistance() -> Float? {
        guard !referenceBuffer.isEmpty, !queryBuffer.isEmpty else { return nil }

        if isColdStart {
            return directFrameDistance()
        }

        return constrainedDTW()
    }

    func reset() {
        referenceBuffer.removeAll()
        queryBuffer.removeAll()
        isColdStart = true
    }

    // MARK: - Private

    private func updateColdStartState() {
        let minFrames = windowSize / 2
        isColdStart = referenceBuffer.count < minFrames || queryBuffer.count < minFrames
    }

    private func directFrameDistance() -> Float {
        guard let refLast = referenceBuffer.last, let queryLast = queryBuffer.last else { return 1.0 }
        return euclideanDistance(refLast, queryLast)
    }

    private func constrainedDTW() -> Float {
        let n = referenceBuffer.count
        let m = queryBuffer.count

        var dtw = [[Float]](repeating: [Float](repeating: Float.infinity, count: m + 1), count: n + 1)
        dtw[0][0] = 0

        for i in 1...n {
            let jStart = max(1, i - bandWidth)
            let jEnd = min(m, i + bandWidth)
            for j in jStart...jEnd {
                let cost = euclideanDistance(referenceBuffer[i - 1], queryBuffer[j - 1])
                dtw[i][j] = cost + min(dtw[i-1][j], dtw[i][j-1], dtw[i-1][j-1])
            }
        }

        let pathLength = Float(max(n, m))
        return dtw[n][m] / pathLength
    }

    private func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
        let count = min(a.count, b.count)
        var sum: Float = 0
        for i in 0..<count {
            let diff = a[i] - b[i]
            sum += diff * diff
        }
        return sqrt(sum)
    }
}
