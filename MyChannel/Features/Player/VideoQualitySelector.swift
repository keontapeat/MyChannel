import SwiftUI

struct VideoQualitySelector: View {
    @Binding var selectedQuality: VideoQuality
    let onQualitySelected: (VideoQuality) -> Void

    var body: some View {
        PlayerOptionSelectionSheet(
            title: "Video Quality",
            subtitle: "Choose your preferred video quality",
            items: VideoQuality.allCases.map { quality in
                PlayerOptionSelectionItem(
                    id: quality.displayName,
                    title: quality.displayName,
                    subtitle: quality == .auto ? "Adapts to your connection" : "\(quality.resolution.width) × \(quality.resolution.height)"
                )
            },
            selectedID: selectedQuality.displayName,
            onSelect: { item in
                guard let quality = VideoQuality.allCases.first(where: { $0.displayName == item.id }) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedQuality = quality
                }
                onQualitySelected(quality)
            }
        )
    }
}

struct VideoQualitySelector_Previews: PreviewProvider {
    static var previews: some View {
        VideoQualitySelector(
            selectedQuality: .constant(.auto),
            onQualitySelected: { quality in
                print("Selected quality: \(quality.displayName)")
            }
        )
    }
}