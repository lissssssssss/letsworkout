import Foundation
import simd

struct JointError {
    let joint: JointAngle.JointType
    let deviation: Float // 0~1, percentage of max deviation
}

struct ScoreResult {
    let score: Float // 0~100
    let feedback: String?
    let jointErrors: [JointError]
}

final class SimilarityScorer {
    private let angleWeight: Float = 0.6
    private let distanceWeight: Float = 0.4

    func computeScore(
        referenceAngles: [JointAngle],
        queryAngles: [JointAngle],
        referenceSkeleton: NormalizedSkeleton,
        querySkeleton: NormalizedSkeleton,
        dtwDistance: Float?
    ) -> ScoreResult {
        let angleScore = computeAngleScore(reference: referenceAngles, query: queryAngles)
        let distanceScore = computeCosineScore(reference: referenceSkeleton, query: querySkeleton)

        var rawScore = angleScore * angleWeight + distanceScore * distanceWeight

        if let dtw = dtwDistance {
            let dtwPenalty = min(dtw * 10, 20.0)
            rawScore = max(0, rawScore - dtwPenalty)
        }

        let finalScore = max(0, min(100, rawScore))
        let errors = computeJointErrors(reference: referenceAngles, query: queryAngles)
        let feedback = generateFeedback(errors: errors)

        return ScoreResult(score: finalScore, feedback: feedback, jointErrors: errors)
    }

    private func computeAngleScore(reference: [JointAngle], query: [JointAngle]) -> Float {
        var totalError: Float = 0
        var validCount: Float = 0

        for i in 0..<min(reference.count, query.count) {
            guard reference[i].isValid, query[i].isValid else { continue }
            let error = abs(reference[i].angle - query[i].angle)
            let normalizedError = error / Float.pi
            totalError += normalizedError
            validCount += 1
        }

        guard validCount > 0 else { return 50 }
        let avgError = totalError / validCount
        return (1 - avgError) * 100
    }

    private func computeCosineScore(reference: NormalizedSkeleton, query: NormalizedSkeleton) -> Float {
        let keyIndices = [
            PoseLandmarkIndex.leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]

        var dotProduct: Float = 0
        var magA: Float = 0
        var magB: Float = 0

        for idx in keyIndices {
            let a = reference[idx]
            let b = query[idx]
            dotProduct += simd_dot(a, b)
            magA += simd_length_squared(a)
            magB += simd_length_squared(b)
        }

        guard magA > 0, magB > 0 else { return 50 }

        let cosine = dotProduct / (sqrt(magA) * sqrt(magB))
        let score = (cosine + 1) / 2 * 100
        return max(0, min(100, score))
    }

    private func computeJointErrors(reference: [JointAngle], query: [JointAngle]) -> [JointError] {
        var errors: [JointError] = []
        for i in 0..<min(reference.count, query.count) {
            guard reference[i].isValid, query[i].isValid else { continue }
            let deviation = abs(reference[i].angle - query[i].angle) / Float.pi
            if deviation > 0.15 {
                errors.append(JointError(joint: reference[i].joint, deviation: deviation))
            }
        }
        return errors.sorted { $0.deviation > $1.deviation }
    }

    private func generateFeedback(errors: [JointError]) -> String? {
        guard let worst = errors.first else { return nil }

        let jointName: String
        switch worst.joint {
        case .leftShoulder: jointName = "左肩"
        case .rightShoulder: jointName = "右肩"
        case .leftElbow: jointName = "左肘"
        case .rightElbow: jointName = "右肘"
        case .leftHip: jointName = "左髋"
        case .rightHip: jointName = "右髋"
        case .leftKnee: jointName = "左膝"
        case .rightKnee: jointName = "右膝"
        }

        return "注意\(jointName)角度"
    }
}
