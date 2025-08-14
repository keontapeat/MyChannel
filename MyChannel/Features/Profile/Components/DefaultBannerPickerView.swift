import SwiftUI

struct DefaultBannerPickerView: View {
    let userID: String
    let selectedID: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentSelection: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(DefaultProfileBanner.defaults) { banner in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentSelection = banner.id
                                onSelect(banner.id)
                                setSelectedDefaultBannerID(banner.id, for: userID)
                            }
                            HapticManager.shared.impact(style: .light)
                            dismiss()
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                bannerThumbnail(for: banner)
                                    .frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(currentSelection == banner.id ? AppTheme.Colors.primary : Color.clear, lineWidth: 2)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { currentSelection = selectedID }
        }
    }
    
    private func bannerThumbnail(for banner: DefaultProfileBanner) -> some View {
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
                        .overlay(
                            Image(systemName: "play.fill")
                                .foregroundStyle(.white)
                                .font(.system(size: 14, weight: .bold))
                        )
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

#Preview("Default Banners Picker") {
    DefaultBannerPickerView(userID: "demo", selectedID: "b2") { _ in }
        .preferredColorScheme(.light)
}