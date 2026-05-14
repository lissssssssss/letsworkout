import Foundation

struct DeviceProfile {
    let chipGeneration: ChipGeneration
    let supportsParallelInference: Bool
    let recommendedFPS: Int
    let useFullModel: Bool

    enum ChipGeneration: Comparable {
        case a13, a14, a15, a15Pro, a16, a16Pro, a17Pro, unknown

        var displayName: String {
            switch self {
            case .a13: return "A13"
            case .a14: return "A14"
            case .a15: return "A15"
            case .a15Pro: return "A15 Pro"
            case .a16: return "A16"
            case .a16Pro: return "A16 Pro"
            case .a17Pro: return "A17 Pro"
            case .unknown: return "Unknown"
            }
        }
    }
}

final class DeviceCapability {
    static let current = DeviceCapability()

    let profile: DeviceProfile

    var supportsParallelInference: Bool { profile.supportsParallelInference }
    var recommendedFPS: Int { profile.recommendedFPS }
    var useFullModel: Bool { profile.useFullModel }

    private init() {
        let chip = Self.detectChip()
        self.profile = Self.buildProfile(for: chip)
    }

    private static func detectChip() -> DeviceProfile.ChipGeneration {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? ""
            }
        }

        if machine.contains("iPhone14") { return .a15 }
        if machine.contains("iPhone15") { return .a16 }
        if machine.contains("iPhone16") { return .a17Pro }
        if machine.contains("iPhone13") { return .a14 }
        if machine.contains("iPhone12") { return .a13 }
        return .unknown
    }

    private static func buildProfile(for chip: DeviceProfile.ChipGeneration) -> DeviceProfile {
        switch chip {
        case .a17Pro, .a16Pro:
            return DeviceProfile(chipGeneration: chip, supportsParallelInference: true, recommendedFPS: 25, useFullModel: true)
        case .a16, .a15Pro, .a15:
            return DeviceProfile(chipGeneration: chip, supportsParallelInference: true, recommendedFPS: 20, useFullModel: false)
        case .a14:
            return DeviceProfile(chipGeneration: chip, supportsParallelInference: false, recommendedFPS: 15, useFullModel: false)
        case .a13:
            return DeviceProfile(chipGeneration: chip, supportsParallelInference: false, recommendedFPS: 15, useFullModel: false)
        case .unknown:
            return DeviceProfile(chipGeneration: chip, supportsParallelInference: false, recommendedFPS: 15, useFullModel: false)
        }
    }
}
