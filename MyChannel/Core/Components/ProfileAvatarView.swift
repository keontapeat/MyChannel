import SwiftUI

struct ProfileAvatarView: View {
    let urlString: String?
    let size: CGFloat
    var showsRing: Bool = false

    private var url: URL? {
        guard let s = urlString, !s.isEmpty else { return nil }
        return URL(string: s)
    }

    var body: some View {
        ZStack {
            if let url {
                AppAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if showsRing {
                Circle().stroke(Color.white.opacity(0.8), lineWidth: 2)
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 4)
        .accessibilityLabel("Profile Avatar")
    }

    private var placeholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.96), Color(white: 0.90)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: max(14, size * 0.42), weight: .semibold))
                    .foregroundColor(.secondary)
            )
    }
}

#Preview("ProfileAvatarView – Asset & Remote") {
    VStack(spacing: 24) {
        // Asset-based avatar (requires "UserProfileAvatar" in Assets)
        ProfileAvatarView(urlString: "asset://UserProfileAvatar", size: 64, showsRing: true)

        // Remote avatar
        ProfileAvatarView(urlString: "https://i.pravatar.cc/200?u=mychannel_demo", size: 64, showsRing: true)

        // Placeholder (no URL)
        ProfileAvatarView(urlString: nil, size: 64, showsRing: false)
    }
    .padding()
    .preferredColorScheme(.light)
}