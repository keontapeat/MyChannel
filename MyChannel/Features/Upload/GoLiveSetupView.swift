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
    @State private var isStarting = false
    @State private var createdStream: FirestoreLiveStream? = nil
    @State private var showBroadcast = false
    @State private var errorMessage: String? = nil
    
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
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }

                Section {
                    Button {
                        Task {
                            isStarting = true
                            errorMessage = nil
                            do {
                                let stream = try await LiveStreamManager.shared.goLive(
                                    title: title.isEmpty ? "Untitled Live" : title,
                                    category: category,
                                    isPublic: isPublic,
                                    enableChat: enableChat,
                                    saveReplay: saveReplay
                                )
                                createdStream = stream
                                HapticManager.shared.impact(style: .heavy)
                                showBroadcast = true
                            } catch {
                                errorMessage = error.localizedDescription
                            }
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
            .fullScreenCover(isPresented: $showBroadcast) {
                if let stream = createdStream {
                    LiveBroadcastView(stream: stream) {
                        showBroadcast = false
                        onStart(LiveConfig(
                            title: stream.title,
                            isPublic: stream.isPublic,
                            enableChat: stream.enableChat,
                            saveReplay: stream.saveReplay,
                            category: stream.category
                        ))
                        dismiss()
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