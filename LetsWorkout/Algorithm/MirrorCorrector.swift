import Foundation
import simd

final class MirrorCorrector {
    func correct(_ skeleton: NormalizedSkeleton, isMirrored: Bool) -> NormalizedSkeleton {
        guard isMirrored else { return skeleton }

        let mirrored = skeleton.points.map { point -> SIMD3<Float> in
            SIMD3<Float>(-point.x, point.y, point.z)
        }

        var swapped = mirrored
        swap(&swapped, leftIndex: PoseLandmarkIndex.leftShoulder.rawValue, rightIndex: PoseLandmarkIndex.rightShoulder.rawValue)
        swap(&swapped, leftIndex: PoseLandmarkIndex.leftElbow.rawValue, rightIndex: PoseLandmarkIndex.rightElbow.rawValue)
        swap(&swapped, leftIndex: PoseLandmarkIndex.leftWrist.rawValue, rightIndex: PoseLandmarkIndex.rightWrist.rawValue)
        swap(&swapped, leftIndex: PoseLandmarkIndex.leftHip.rawValue, rightIndex: PoseLandmarkIndex.rightHip.rawValue)
        swap(&swapped, leftIndex: PoseLandmarkIndex.leftKnee.rawValue, rightIndex: PoseLandmarkIndex.rightKnee.rawValue)
        swap(&swapped, leftIndex: PoseLandmarkIndex.leftAnkle.rawValue, rightIndex: PoseLandmarkIndex.rightAnkle.rawValue)

        return NormalizedSkeleton(points: swapped, timestamp: skeleton.timestamp)
    }

    private func swap(_ points: inout [SIMD3<Float>], leftIndex: Int, rightIndex: Int) {
        let temp = points[leftIndex]
        points[leftIndex] = points[rightIndex]
        points[rightIndex] = temp
    }
}
