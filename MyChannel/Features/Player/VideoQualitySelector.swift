import SwiftUI

struct VideoQualitySelector: View {
    @Binding var selectedQuality: VideoQuality
    let onQualitySelected: (VideoQuality) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("Video Quality")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Choose your preferred video quality")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Quality List
                List {
                    ForEach(VideoQuality.allCases, id: \.self) { quality in
                        QualityRow(
                            quality: quality,
                            isSelected: quality == selectedQuality
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedQuality = quality
                            }
                            
                            // Haptic feedback
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            
                            onQualitySelected(quality)
                            
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

// MARK: - Quality Row Component
private struct QualityRow: View {
    let quality: VideoQuality
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Quality icon
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
                    Text(quality.displayName)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(.primary)
                    
                    if quality != .auto {
                        Text("\(quality.resolution.width) × \(quality.resolution.height)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Adapts to your connection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
    VideoQualitySelector(
        selectedQuality: .constant(.auto),
        onQualitySelected: { quality in
            print("Selected quality: \(quality.displayName)")
        }
    )
}