import SwiftUI

struct VideoDetailUpNextBar: View {
    let sourceVideo: Video
    let next: Video
    @Binding var autoplayEnabled: Bool
    let onTap: () -> Void
    let onImpression: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial)
                .frame(width: 56, height: 32)
                .overlay(Text("Up next").font(.caption2))
            Text(next.title)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer()
            Toggle(isOn: $autoplayEnabled) { Text("Autoplay").font(.caption2) }
                .labelsHidden()
                .tint(AppTheme.Colors.primary)
            Button(action: onTap) {
                Image(systemName: "play.fill")
                    .foregroundColor(AppTheme.Colors.primary)
                    .font(.title2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .onAppear(perform: onImpression)
    }
}
