import SwiftUI

struct WorkoutView: View {
    @ObservedObject var coordinator: SessionCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                scoreDisplay
                Spacer()
                controlBar
            }
            .padding()

            if case .paused(let reason) = coordinator.session.state {
                pauseOverlay(reason: reason)
            }
        }
    }

    // MARK: - Components

    private var topBar: some View {
        HStack {
            Button(action: { stopAndDismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "clock")
                Text(formatDuration(coordinator.session.duration))
            }
            .font(.subheadline.monospacedDigit())
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.15))
            .cornerRadius(20)

            Spacer()

            statusIndicator
        }
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private var scoreDisplay: some View {
        VStack(spacing: 20) {
            ScoreGaugeView(score: coordinator.session.currentScore)

            if let feedback = coordinator.session.currentFeedback {
                Text(feedback)
                    .font(.headline)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(10)
            }

            HStack(spacing: 30) {
                VStack {
                    Text("平均")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(coordinator.session.averageScore))")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }

                VStack {
                    Text("模式")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(coordinator.inputMode == .live ? "实时" : "模拟")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 40) {
            Button(action: {
                if case .active = coordinator.session.state {
                    coordinator.pauseWorkout(reason: .userManual)
                } else {
                    coordinator.resumeWorkout()
                }
            }) {
                Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            Button(action: { stopAndDismiss() }) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
            }
        }
    }

    private func pauseOverlay(reason: SessionState.PauseReason) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "pause.circle")
                .font(.system(size: 48))
                .foregroundColor(.yellow)
            Text(pauseReasonText(reason))
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            if reason == .userManual {
                Button("继续") { coordinator.resumeWorkout() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
    }

    // MARK: - Helpers

    private var isPaused: Bool {
        if case .paused = coordinator.session.state { return true }
        return false
    }

    private var statusColor: Color {
        switch coordinator.session.state {
        case .active: return .green
        case .paused: return .yellow
        default: return .gray
        }
    }

    private var statusText: String {
        switch coordinator.session.state {
        case .active: return "跟练中"
        case .paused: return "暂停"
        case .preparing: return "准备中"
        default: return ""
        }
    }

    private func pauseReasonText(_ reason: SessionState.PauseReason) -> String {
        switch reason {
        case .extensionDied: return "录屏已断开"
        case .cameraInterrupted: return "摄像头被占用"
        case .pipClosed: return "画中画已关闭\n请重新开启以继续跟练"
        case .noPoseDetected: return "未检测到人体动作\n请确保全身在画面内"
        case .thermalThrottling: return "设备过热\n建议稍作休息"
        case .userManual: return "已暂停"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func stopAndDismiss() {
        coordinator.stopWorkout()
        dismiss()
    }
}
