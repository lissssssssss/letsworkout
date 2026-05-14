import SwiftUI

struct ScoreOverlayView: View {
    let score: Float
    let feedback: String?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(score))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                    if let feedback = feedback {
                        Text(feedback)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(6)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.4))
                .cornerRadius(12)
                .padding(.trailing, 16)
                .padding(.top, 60)
            }
            Spacer()
        }
    }

    private var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        default: return .orange
        }
    }
}
