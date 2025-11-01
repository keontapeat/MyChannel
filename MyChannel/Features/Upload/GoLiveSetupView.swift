import SwiftUI

struct GoLiveSetupView: View {
    struct LiveConfig {
        var title: String
        var isPublic: Bool
        var enableChat: Bool
        var saveReplay: Bool
        var category: String
    }
    
    @Environment(\.dismiss) private var dismiss
    let onClose: () -> Void
    let onStart: (LiveConfig) -> Void
    
    @State private var title: String = ""
    @State private var isPublic: Bool = true
    @State private var enableChat: Bool = true
    @State private var saveReplay: Bool = true
    @State private var category: String = "General"
    @State private var ingestInfo: (id: String, key: String, rtmp: String, hls: String)? = nil
    @State private var isStarting = false
    
    private let categories = ["General", "Gaming", "Music", "Education", "Lifestyle", "Sports"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Live title", text: $title)
                        .textInputAutocapitalization(.sentences)
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                }
                
                Section("Visibility") {
                    Toggle("Public", isOn: $isPublic)
                    Toggle("Live chat", isOn: $enableChat)
                    Toggle("Save replay", isOn: $saveReplay)
                }
                
                Section {
                    if let ingest = ingestInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RTMP URL").font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Text(ingest.rtmp).font(.footnote).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Button("Copy") { UIPasteboard.general.string = ingest.rtmp }
                            }
                            Text("Stream Key").font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Text(ingest.key).font(.footnote).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Button("Copy") { UIPasteboard.general.string = ingest.key }
                            }
                            Text("HLS Preview").font(.caption).foregroundStyle(.secondary)
                            Text(ingest.hls).font(.footnote).lineLimit(1).truncationMode(.middle)
                        }
                    }
                    Button {
                        Task {
                            isStarting = true
                            let config = LiveConfig(
                                title: title.isEmpty ? "Untitled Live" : title,
                                isPublic: isPublic,
                                enableChat: enableChat,
                                saveReplay: saveReplay,
                                category: category
                            )
                            do {
                                let uid = AppState.shared.currentUser?.id ?? User.sampleUsers.first?.id ?? ""
                                let req = LiveControlService.StartRequest(title: config.title, description: nil, category: config.category, isPublic: config.isPublic, enableChat: config.enableChat, saveReplay: config.saveReplay, userId: uid)
                                let resp = try await LiveControlService.shared.startLive(req)
                                ingestInfo = (resp.id, resp.streamKey, resp.rtmpUrl, resp.hlsUrl)
                                HapticManager.shared.impact(style: .heavy)
                                onStart(config)
                            } catch { }
                            isStarting = false
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isStarting { ProgressView().progressViewStyle(.circular) }
                            Label("Start Live", systemImage: "dot.radiowaves.left.and.right")
                                .font(.system(size: 17, weight: .semibold))
                            Spacer()
                        }
                    }
                    .disabled(isStarting || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Go Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        onClose()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

#Preview("GoLiveSetupView") {
    GoLiveSetupView {
        // onClose
    } onStart: { _ in
        // onStart
    }
}