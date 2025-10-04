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
                    Button {
                        let config = LiveConfig(
                            title: title.isEmpty ? "Untitled Live" : title,
                            isPublic: isPublic,
                            enableChat: enableChat,
                            saveReplay: saveReplay,
                            category: category
                        )
                        HapticManager.shared.impact(style: .heavy)
                        onStart(config)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Start Live", systemImage: "dot.radiowaves.left.and.right")
                                .font(.system(size: 17, weight: .semibold))
                            Spacer()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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