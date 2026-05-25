import SwiftUI

struct PlaybackSpeedSelector: View {
    @Binding var selectedSpeed: Float
    let onSpeedSelected: (Float) -> Void
    
    private let speeds: [PlaybackSpeedOption] = [
        PlaybackSpeedOption(value: 0.25, displayName: "0.25x", subtitle: "Slowest"),
        PlaybackSpeedOption(value: 0.5, displayName: "0.5x", subtitle: "Slow"),
        PlaybackSpeedOption(value: 0.75, displayName: "0.75x", subtitle: "Slightly slow"),
        PlaybackSpeedOption(value: 1.0, displayName: "1x", subtitle: "Normal"),
        PlaybackSpeedOption(value: 1.25, displayName: "1.25x", subtitle: "Slightly fast"),
        PlaybackSpeedOption(value: 1.5, displayName: "1.5x", subtitle: "Fast"),
        PlaybackSpeedOption(value: 1.75, displayName: "1.75x", subtitle: "Faster"),
        PlaybackSpeedOption(value: 2.0, displayName: "2x", subtitle: "Fastest")
    ]

    var body: some View {
        PlayerOptionSelectionSheet(
            title: "Playback Speed",
            subtitle: "Choose your preferred playback speed",
            items: speeds.map { speedOption in
                PlayerOptionSelectionItem(
                    id: String(speedOption.value),
                    title: speedOption.displayName,
                    subtitle: speedOption.subtitle
                )
            },
            selectedID: String(selectedSpeed),
            onSelect: { item in
                guard let option = speeds.first(where: { String($0.value) == item.id }) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedSpeed = option.value
                }
                onSpeedSelected(option.value)
            }
        )
    }
}

// MARK: - Speed Option Model
private struct PlaybackSpeedOption {
    let value: Float
    let displayName: String
    let subtitle: String
}

// MARK: - Speed Row Component
#Preview {
    PlaybackSpeedSelector(
        selectedSpeed: .constant(1.0),
        onSpeedSelected: { speed in
            print("Selected speed: \(speed)x")
        }
    )
}