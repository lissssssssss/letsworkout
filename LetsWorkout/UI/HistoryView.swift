import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var records: [WorkoutRecordItem] = []

    var body: some View {
        NavigationView {
            Group {
                if records.isEmpty {
                    emptyState
                } else {
                    recordList
                }
            }
            .navigationTitle("跟练记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear { loadRecords() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("还没有跟练记录")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("开始第一次跟练吧")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var recordList: some View {
        List(records) { record in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.date, style: .date)
                        .font(.subheadline.bold())
                    Text("时长 \(record.formattedDuration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(record.averageScore))分")
                        .font(.title3.bold())
                        .foregroundColor(scoreColor(record.averageScore))
                    Text("平均得分")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func scoreColor(_ score: Float) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        default: return .orange
        }
    }

    private func loadRecords() {
        records = WorkoutStore.shared.fetchAll()
    }
}

struct WorkoutRecordItem: Identifiable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let averageScore: Float

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d分%02d秒", minutes, seconds)
    }
}
