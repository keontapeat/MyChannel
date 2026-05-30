// ⚡ PERFORMANCE: Extracted from EditProfileView.swift — independent compilation unit.
// Banner preview, text fields, and picker components compile in parallel.
import SwiftUI
import AVKit
import PhotosUI

// MARK: - Simple inline preview for banner video
struct VideoBannerPreview: View {
    let url: URL
    let isMuted: Bool
    let contentMode: UserBannerContentMode
    @State private var player = AVPlayer()
    @State private var loopObserver: NSObjectProtocol?
    var body: some View {
        FlicksPlayerLayerView(player: player, videoGravity: contentMode == .fill ? .resizeAspectFill : .resizeAspect)
            .onAppear {
                let item = AVPlayerItem(url: url)
                loopObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
                    item.seek(to: .zero, completionHandler: nil)
                    player.play()
                }
                player.replaceCurrentItem(with: item)
                player.isMuted = isMuted
                player.play()
            }
            .onChange(of: isMuted) { muted in
                player.isMuted = muted
            }
            .onDisappear {
                player.pause()
                if let obs = loopObserver {
                    NotificationCenter.default.removeObserver(obs)
                    loopObserver = nil
                }
            }
    }
}

struct UIKitBannerVideoPicker: UIViewControllerRepresentable {
    let onPick: (URL?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeHigh
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: UIKitBannerVideoPicker
        
        init(parent: UIKitBannerVideoPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let url = info[.mediaURL] as? URL
            parent.onPick(url)
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onPick(nil)
            parent.dismiss()
        }
    }
}

// MARK: - Modern Text Field
struct ModernTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let prefix: String?
    let placeholder: String
    let keyboardType: UIKeyboardType
    
    @FocusState private var isFocused: Bool
    
    init(title: String, text: Binding<String>, icon: String, prefix: String? = nil, placeholder: String = "", keyboardType: UIKeyboardType = .default) {
        self.title = title
        self._text = text
        self.icon = icon
        self.prefix = prefix
        self.placeholder = placeholder
        self.keyboardType = keyboardType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                    .frame(width: 22)
                
                if let prefix = prefix {
                    Text(prefix)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                TextField(placeholder, text: $text)
                    .font(.system(size: 17))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .URL ? .never : .words)
                    .focused($isFocused)
            }
            .padding(18)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.3), lineWidth: isFocused ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

// MARK: - Modern Text Editor
struct ModernTextEditor: View {
    let title: String
    @Binding var text: String
    let icon: String
    let placeholder: String
    let maxLength: Int
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                Text("\(text.count)/\(maxLength)")
                    .font(.system(size: 12))
                    .foregroundColor(text.count > maxLength ? .red : AppTheme.Colors.textTertiary)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                        .frame(width: 20)
                    
                    Text("About You")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .onChange(of: text) { newValue in
                            if newValue.count > maxLength {
                                text = String(newValue.prefix(maxLength))
                            }
                        }
                    
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 100)
            }
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.2), lineWidth: isFocused ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

// MARK: - Privacy Toggle Row
struct PrivacyToggleRow: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
        }
        .padding(16)
    }
}

struct DefaultProfileBanner: Identifiable, Hashable {
    enum Kind { case image, video }
    let id: String
    let title: String
    let subtitle: String
    let kind: Kind
    let assetURL: String
    let previewURL: String?
    
    static let all: [DefaultProfileBanner] = [
        .init(id: "b1", title: "Golden Hour Mountains", subtitle: "Warm cinematic tones", kind: .image, assetURL: "https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=1600&q=80", previewURL: nil),
        .init(id: "b2", title: "Ocean Sunset", subtitle: "Soft gradients and waves", kind: .image, assetURL: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1600&q=80", previewURL: nil),
        .init(id: "b3", title: "City Lights", subtitle: "Modern urban vibe", kind: .image, assetURL: "https://images.unsplash.com/photo-1499346030926-9a72daac6c63?w=1600&q=80", previewURL: nil),
        .init(id: "b4", title: "Cinematic Nature", subtitle: "Subtle motion video", kind: .video, assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4", previewURL: "https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=1600&q=80"),
        .init(id: "b5", title: "Abstract Flow", subtitle: "Minimal gradient waves", kind: .image, assetURL: "https://images.unsplash.com/photo-154988033865ddcdfd017b?w=1600&q=80", previewURL: nil),
        .init(id: "b6", title: "Sintel Trailer", subtitle: "Cinematic video banner", kind: .video, assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4", previewURL: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1600&q=80"),
        .init(id: "b7", title: "Joyrides", subtitle: "Dynamic city motion", kind: .video, assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4", previewURL: "https://images.unsplash.com/photo-1493238792000-8113da705763?w=1600&q=80"),
        .init(id: "b8", title: "Escapes", subtitle: "Travel cinematic", kind: .video, assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4", previewURL: "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=1600&q=80"),
        .init(id: "b9", title: "Elephant Dream", subtitle: "Moody animation", kind: .video, assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4", previewURL: "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=1600&q=80")
    ]
}

struct DefaultBannerPickerView: View {
    enum Mode { case image, video }
    let mode: Mode
    let onSelect: (DefaultProfileBanner) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var filtered: [DefaultProfileBanner] {
        DefaultProfileBanner.all.filter { mode == .image ? $0.kind == .image : $0.kind == .video }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(filtered) { banner in
                        Button {
                            onSelect(banner)
                            dismiss()
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                bannerThumb(banner)
                                    .frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(banner.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(banner.subtitle)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                .padding(10)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Choose Banner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }
    
    private func bannerThumb(_ banner: DefaultProfileBanner) -> some View {
        Group {
            if banner.kind == .video {
                ZStack {
                    CachedAsyncImage(url: URL(string: banner.previewURL ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 14).fill(AppTheme.Colors.textTertiary.opacity(0.15))
                    }
                    Circle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 32, height: 32)
                        .overlay(Image(systemName: "play.fill").foregroundStyle(.white).font(.system(size: 14, weight: .bold)))
                }
            } else {
                CachedAsyncImage(url: URL(string: banner.assetURL)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 14).fill(AppTheme.Colors.textTertiary.opacity(0.15))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView(user: .constant(User.sampleUsers[0]))
    }
    .environmentObject(AuthenticationManager.shared)
    .environmentObject(AppState())
    .preferredColorScheme(.light)
}