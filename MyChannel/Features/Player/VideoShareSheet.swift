import SwiftUI

// MARK: - 🔥 FIX: Native iOS Share Sheet using UIActivityViewController
/// Proper share sheet that uses iOS's native sharing functionality
struct VideoShareSheet: View {
    let items: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    var onComplete: ((Bool) -> Void)? = nil

    var body: some View {
        NativeShareSheet(
            items: items,
            excludedActivityTypes: excludedActivityTypes,
            onComplete: onComplete
        )
    }
}

// MARK: - Enhanced Video Share Sheet with Preview
/// A more polished share sheet with video preview before sharing
struct EnhancedVideoShareSheet: View {
    let video: Video
    let shareURL: String
    @Environment(\.dismiss) private var dismiss
    @State private var showingNativeShare = false
    @State private var copiedToClipboard = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                // Header
                HStack {
                    Text("Share")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.Colors.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Video Preview Card
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 100, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(2)
                        
                        Text(video.creator.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(12)
                .background(AppTheme.Colors.surface)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                // Share Options Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    // Copy Link
                    ShareOptionButton(
                        icon: "link",
                        title: copiedToClipboard ? "Copied!" : "Copy Link",
                        color: copiedToClipboard ? .green : AppTheme.Colors.primary
                    ) {
                        UIPasteboard.general.string = shareURL
                        copiedToClipboard = true
                        HapticManager.shared.notification(type: .success)
                        
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            copiedToClipboard = false
                        }
                    }
                    
                    // Messages
                    ShareOptionButton(icon: "message.fill", title: "Messages", color: .green) {
                        shareViaMessages()
                    }
                    
                    // WhatsApp
                    ShareOptionButton(icon: "bubble.left.fill", title: "WhatsApp", color: Color(red: 0.07, green: 0.72, blue: 0.38)) {
                        shareViaWhatsApp()
                    }
                    
                    // More Options (Native Share)
                    ShareOptionButton(icon: "square.and.arrow.up", title: "More", color: .gray) {
                        showingNativeShare = true
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                
                Spacer()
            }
            .background(AppTheme.Colors.background)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingNativeShare) {
            VideoShareSheet(items: [shareURL])
        }
    }
    
    private func shareViaMessages() {
        let encodedURL = shareURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shareURL
        if let url = URL(string: "sms:&body=Check out this video: \(encodedURL)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func shareViaWhatsApp() {
        let encodedURL = shareURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shareURL
        if let url = URL(string: "whatsapp://send?text=Check out this video: \(encodedURL)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // WhatsApp not installed - show native share instead
                showingNativeShare = true
            }
        }
    }
}

// MARK: - Share Option Button
struct ShareOptionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            action()
        }) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(color, in: Circle())
                    .shadow(color: color.opacity(0.3), radius: 6, x: 0, y: 3)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("Native Share Sheet") {
    VideoShareSheet(items: ["https://mychannel.app/watch?v=abc123"])
}

#Preview("Enhanced Share Sheet") {
    EnhancedVideoShareSheet(
        video: Video.sampleVideos[0],
        shareURL: "https://mychannel.app/watch?v=abc123"
    )
    .preferredColorScheme(.dark)
}
