import Foundation

protocol ThermalMonitorDelegate: AnyObject {
    func thermalMonitor(_ monitor: ThermalMonitor, didChangeState state: ProcessInfo.ThermalState)
    func thermalMonitorRecommendThrottling(_ monitor: ThermalMonitor, targetFPS: Int)
}

final class ThermalMonitor {
    weak var delegate: ThermalMonitorDelegate?

    private var isMonitoring = false
    private let baseFPS: Int

    init(baseFPS: Int = 30) {
        self.baseFPS = baseFPS
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }

    func stopMonitoring() {
        isMonitoring = false
        NotificationCenter.default.removeObserver(self)
    }

    var currentState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }

    var recommendedFPS: Int {
        fpsForState(currentState)
    }

    @objc private func thermalStateDidChange(_ notification: Notification) {
        let state = ProcessInfo.processInfo.thermalState
        let fps = fpsForState(state)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.thermalMonitor(self, didChangeState: state)
            self.delegate?.thermalMonitorRecommendThrottling(self, targetFPS: fps)
        }
    }

    private func fpsForState(_ state: ProcessInfo.ThermalState) -> Int {
        switch state {
        case .nominal: return baseFPS
        case .fair: return max(baseFPS - 5, 15)
        case .serious: return 10
        case .critical: return 5
        @unknown default: return 15
        }
    }

    deinit {
        stopMonitoring()
    }
}
