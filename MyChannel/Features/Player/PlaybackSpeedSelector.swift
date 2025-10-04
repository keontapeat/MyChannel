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
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("Playback Speed")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Choose your preferred playback speed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Speed List
                List {
                    ForEach(speeds, id: \.value) { speedOption in
                        SpeedRow(
                            speedOption: speedOption,
                            isSelected: speedOption.value == selectedSpeed
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSpeed = speedOption.value
                            }
                            
                            // Haptic feedback
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            
                            onSpeedSelected(speedOption.value)
                            
                            // Dismiss after a short delay for visual feedback
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                dismiss()
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                    .fontWeight(.medium)
                }
            }
        }
    }
}

// MARK: - Speed Option Model
private struct PlaybackSpeedOption {
    let value: Float
    let displayName: String
    let subtitle: String
}

// MARK: - Speed Row Component
private struct SpeedRow: View {
    let speedOption: PlaybackSpeedOption
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Speed icon
                Circle()
                    .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.accentColor, lineWidth: isSelected ? 0 : 1.5)
                    )
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(speedOption.displayName)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(.primary)
                    
                    Text(speedOption.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        )
    }
}

#Preview {
    PlaybackSpeedSelector(
        selectedSpeed: .constant(1.0),
        onSpeedSelected: { speed in
            print("Selected speed: \(speed)x")
        }
    )
}