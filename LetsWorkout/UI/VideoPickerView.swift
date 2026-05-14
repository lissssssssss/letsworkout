import SwiftUI
import PhotosUI
import AVFoundation

struct VideoPickerView: View {
    @Binding var selectedURL: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    Text("选择参考视频")
                        .font(.title2.bold())
                    Text("选择一个健身/运动视频作为跟练目标\n也可以不选，使用内置示范视频")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                Spacer()

                PhotosPicker(selection: $selectedItem, matching: .videos) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("从相册选择视频")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(14)
                }

                if selectedURL != nil {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("视频已选择")
                            .foregroundColor(.green)
                    }
                    .font(.subheadline)
                }

                Button("使用内置示范视频") {
                    selectedURL = nil
                    dismiss()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    await loadVideo(from: newItem)
                }
            }
        }
    }

    private func loadVideo(from item: PhotosPickerItem?) async {
        guard let item = item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mp4")
                try data.write(to: tempURL)
                await MainActor.run {
                    selectedURL = tempURL
                }
            }
        } catch {
            print("[VideoPicker] Failed to load video: \(error)")
        }
    }
}
