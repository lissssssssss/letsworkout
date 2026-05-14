import Foundation
import simd

struct NormalizedSkeleton {
    let points: [SIMD3<Float>]
    let timestamp: TimeInterval

    subscript(index: PoseLandmarkIndex) -> SIMD3<Float> {
        points[index.rawValue]
    }
}

final class SkeletonNormalizer {
    func normalize(_ pose: PoseResult) -> NormalizedSkeleton? {
        let landmarks = pose.landmarks
        guard landmarks.count == PoseResult.landmarkCount else { return nil }

        let leftHip = landmarks[PoseLandmarkIndex.leftHip.rawValue]
        let rightHip = landmarks[PoseLandmarkIndex.rightHip.rawValue]

        guard leftHip.isValid, rightHip.isValid else { return nil }

        let hipCenter = SIMD3<Float>(
            (leftHip.x + rightHip.x) / 2,
            (leftHip.y + rightHip.y) / 2,
            (leftHip.z + rightHip.z) / 2
        )

        let leftShoulder = landmarks[PoseLandmarkIndex.leftShoulder.rawValue]
        let rightShoulder = landmarks[PoseLandmarkIndex.rightShoulder.rawValue]

        var scaleFactor: Float = 1.0
        if leftShoulder.isValid, rightShoulder.isValid {
            let shoulderWidth = sqrt(
                pow(leftShoulder.x - rightShoulder.x, 2) +
                pow(leftShoulder.y - rightShoulder.y, 2)
            )
            if shoulderWidth > 0.01 {
                scaleFactor = 1.0 / shoulderWidth
            }
        }

        let normalized = landmarks.map { lm -> SIMD3<Float> in
            guard lm.isValid else { return SIMD3<Float>(0, 0, 0) }
            return SIMD3<Float>(
                (lm.x - hipCenter.x) * scaleFactor,
                (lm.y - hipCenter.y) * scaleFactor,
                (lm.z - hipCenter.z) * scaleFactor
            )
        }

        return NormalizedSkeleton(points: normalized, timestamp: pose.timestamp)
    }
}
