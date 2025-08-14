import SwiftUI

struct DefaultProfileBanner: Identifiable, Hashable {
    enum Kind { case image, video }
    let id: String
    let title: String
    let subtitle: String
    let kind: Kind
    let assetURL: String
    let previewURL: String?
    
    static let defaults: [DefaultProfileBanner] = [
        DefaultProfileBanner(
            id: "b1",
            title: "Golden Hour Mountains",
            subtitle: "Warm cinematic tones",
            kind: .image,
            assetURL: "https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=1600&q=80",
            previewURL: nil
        ),
        DefaultProfileBanner(
            id: "b2",
            title: "Ocean Sunset",
            subtitle: "Soft gradients and waves",
            kind: .image,
            assetURL: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1600&q=80",
            previewURL: nil
        ),
        DefaultProfileBanner(
            id: "b3",
            title: "City Lights",
            subtitle: "Modern urban vibe",
            kind: .image,
            assetURL: "https://images.unsplash.com/photo-1499346030926-9a72daac6c63?w=1600&q=80",
            previewURL: nil
        ),
        DefaultProfileBanner(
            id: "b4",
            title: "Cinematic Nature",
            subtitle: "Subtle motion video",
            kind: .video,
            assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            previewURL: "https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=1600&q=80"
        ),
        DefaultProfileBanner(
            id: "b5",
            title: "Abstract Flow",
            subtitle: "Minimal gradient waves",
            kind: .image,
            assetURL: "https://images.unsplash.com/photo-154988033865ddcdfd017b?w=1600&q=80",
            previewURL: nil
        ),
        DefaultProfileBanner(
            id: "b6",
            title: "Sintel Trailer",
            subtitle: "Cinematic video banner",
            kind: .video,
            assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
            previewURL: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1600&q=80"
        )
    ]
}

// MARK: - Persistence helpers for default banner selection
func bannerSelectionKey(for userID: String) -> String { "defaultProfileBanner.\(userID)" }

func getSelectedDefaultBannerID(for userID: String) -> String? {
    UserDefaults.standard.string(forKey: bannerSelectionKey(for: userID))
}

func setSelectedDefaultBannerID(_ id: String, for userID: String) {
    UserDefaults.standard.set(id, forKey: bannerSelectionKey(for: userID))
}

func getSelectedDefaultBanner(for userID: String) -> DefaultProfileBanner? {
    if let id = getSelectedDefaultBannerID(for: userID) {
        return DefaultProfileBanner.defaults.first(where: { $0.id == id })
    }
    return nil
}

#Preview("Default Banner Models") {
    List(DefaultProfileBanner.defaults) { item in
        HStack {
            Text(item.title).font(.headline)
            Spacer()
            Text(item.kind == .video ? "Video" : "Image").foregroundStyle(.secondary)
        }
    }
}