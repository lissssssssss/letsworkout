import SwiftUI
import PhotosUI

struct HomeView: View {
    @StateObject private var coordinator = SessionCoordinator()
    @State private var showWorkout = false
    @State private var showHistory = false
    @State private var showVideoPicker = false
    @State private var selectedVideoURL: URL?

    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    Text("LetsWorkout")
                        .font(.largeTitle.bold())
                    Text("AI 运动跟练助手")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    modeIndicator
                }

                Spacer()

                VStack(spacing: 16) {
                    // 选择参考视频
                    Button(action: { showVideoPicker = true }) {
                        HStack {
                            Image(systemName: "video.badge.plus")
                            Text(selectedVideoURL != nil ? "已选择参考视频" : "选择参考视频")
                        }
                        .font(.headline)
                        .foregroundColor(selectedVideoURL != nil ? .green : .blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(14)
                    }

                    // 开始跟练
                    Button(action: { startWorkout() }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("开始跟练")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(14)
                    }

                    // 跟练记录
                    Button(action: { showHistory = true }) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                            Text("跟练记录")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showWorkout) {
                WorkoutView(coordinator: coordinator)
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
            .sheet(isPresented: $showVideoPicker) {
                VideoPickerView(selectedURL: $selectedVideoURL)
            }
        }
    }

    private var modeIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(coordinator.inputMode == .live ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(coordinator.inputMode == .live ? "真机模式" : "模拟器模式")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }

    private func startWorkout() {
        coordinator.startWorkout(referenceVideoURL: selectedVideoURL)
        showWorkout = true
    }
}
