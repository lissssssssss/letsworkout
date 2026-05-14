import Foundation
import simd

struct JointAngle {
    let joint: JointType
    let angle: Float // radians
    let isValid: Bool

    enum JointType: CaseIterable {
        case leftShoulder, rightShoulder
        case leftElbow, rightElbow
        case leftHip, rightHip
        case leftKnee, rightKnee
    }
}

final class JointAngleCalculator {
    func calculate(from skeleton: NormalizedSkeleton, pose: PoseResult) -> [JointAngle] {
        return JointAngle.JointType.allCases.map { joint in
            let (a, b, c) = indices(for: joint)
            let landmarks = pose.landmarks
            let isValid = landmarks[a.rawValue].isValid && landmarks[b.rawValue].isValid && landmarks[c.rawValue].isValid

            let angle: Float
            if isValid {
                angle = calculateAngle(
                    a: skeleton.points[a.rawValue],
                    b: skeleton.points[b.rawValue],
                    c: skeleton.points[c.rawValue]
                )
            } else {
                angle = 0
            }
            return JointAngle(joint: joint, angle: angle, isValid: isValid)
        }
    }

    private func calculateAngle(a: SIMD3<Float>, b: SIMD3<Float>, c: SIMD3<Float>) -> Float {
        let ba = a - b
        let bc = c - b

        let dot = simd_dot(ba, bc)
        let magBA = simd_length(ba)
        let magBC = simd_length(bc)

        guard magBA > 0.001, magBC > 0.001 else { return 0 }

        let cosAngle = dot / (magBA * magBC)
        let clampedCos = max(-1.0, min(1.0, cosAngle))
        return acos(clampedCos)
    }

    private func indices(for joint: JointAngle.JointType) -> (PoseLandmarkIndex, PoseLandmarkIndex, PoseLandmarkIndex) {
        switch joint {
        case .leftShoulder:  return (.leftElbow, .leftShoulder, .leftHip)
        case .rightShoulder: return (.rightElbow, .rightShoulder, .rightHip)
        case .leftElbow:     return (.leftShoulder, .leftElbow, .leftWrist)
        case .rightElbow:    return (.rightShoulder, .rightElbow, .rightWrist)
        case .leftHip:       return (.leftShoulder, .leftHip, .leftKnee)
        case .rightHip:      return (.rightShoulder, .rightHip, .rightKnee)
        case .leftKnee:      return (.leftHip, .leftKnee, .leftAnkle)
        case .rightKnee:     return (.rightHip, .rightKnee, .rightAnkle)
        }
    }
}
