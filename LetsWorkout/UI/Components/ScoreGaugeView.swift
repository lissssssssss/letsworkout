import SwiftUI

struct ScoreGaugeView: View {
    let score: Float

    private var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 12)
                .frame(width: 160, height: 160)

            Circle()
                .trim(from: 0, to: CGFloat(score / 100))
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: score)

            VStack(spacing: 4) {
                Text("\(Int(score))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("分")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
