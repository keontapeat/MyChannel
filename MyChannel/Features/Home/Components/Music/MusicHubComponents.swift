import SwiftUI

struct NewReleaseRowView: View {
    let song: CatalogSong
    let rank: Int
    @ObservedObject private var preview = AudioPreviewPlayer.shared
    
    private var isPlaying: Bool {
        preview.currentTrackId == String(song.id) && preview.isPlaying
    }
    
    var body: some View {
        HStack(spacing: 16) {
            if isPlaying {
                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
                    .frame(width: 24)
            } else {
                Spacer().frame(width: 24)
            }
            
            AppAsyncImage(url: URL(string: song.artworkUrl ?? "")) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5))
                    .overlay(Image(systemName: "music.note").foregroundColor(.secondary))
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "heart")
                    .font(.system(size: 20))
                    .foregroundColor(isPlaying ? .red : .secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isPlaying ? Color.red.opacity(0.08) : Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
        .onTapGesture {
            if let p = song.previewUrl, let u = URL(string: p) {
                let id = String(song.id)
                if preview.currentTrackId == id && preview.isPlaying {
                    preview.pause()
                } else {
                    preview.play(url: u, trackId: id, title: song.title, artist: song.artist, artworkURL: URL(string: song.artworkUrl ?? ""))
                }
                HapticManager.shared.selection()
            }
        }
    }
}

struct PremiumBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 52, height: 52)
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.premiumGradient)
                }
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 62)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct MoodChip: View {
    let mood: MusicMood
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: mood.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(mood.rawValue)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? mood.color : Color(.systemGray5))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? mood.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct MusicSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = .primary
    var showSeeAll: Bool = false
    var seeAllAction: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                }
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if showSeeAll {
                Button {
                    seeAllAction?()
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct MusicWavePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let width = rect.width
        
        path.move(to: CGPoint(x: 0, y: midY))
        
        // Create smooth wave
        for x in stride(from: 0, through: width, by: 5) {
            let relativeX = x / width
            let y = midY + sin(relativeX * .pi * 4) * 20
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

struct EqualizerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPreset: String = "Flat"
    @State private var eqBands: [Double] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    
    let presets = ["Flat", "Rock", "Pop", "Jazz", "Classical", "Hip-Hop", "R&B", "Electronic", "Bass Boost", "Treble Boost"]
    let frequencies = ["32", "64", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preset selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(presets, id: \.self) { preset in
                            Button {
                                selectedPreset = preset
                                applyPreset(preset)
                                HapticManager.shared.impact(style: .light)
                            } label: {
                                Text(preset)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(selectedPreset == preset ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(selectedPreset == preset ? AppTheme.Colors.primary : Color(.systemGray5))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // EQ Sliders
                HStack(spacing: 0) {
                    ForEach(Array(frequencies.enumerated()), id: \.offset) { index, freq in
                        VStack(spacing: 8) {
                            // Value
                            Text(String(format: "%.0f", eqBands[index]))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            // Slider (vertical)
                            GeometryReader { geo in
                                ZStack(alignment: .bottom) {
                                    // Track
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 8)
                                    
                                    // Fill
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.6)],
                                                startPoint: .bottom,
                                                endPoint: .top
                                            )
                                        )
                                        .frame(width: 8, height: max(0, (eqBands[index] + 12) / 24 * geo.size.height))
                                }
                                .frame(maxWidth: .infinity)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let ratio = 1 - (value.location.y / geo.size.height)
                                            let clamped = min(max(ratio, 0), 1)
                                            eqBands[index] = (clamped * 24) - 12
                                        }
                                )
                            }
                            .frame(height: 150)
                            
                            // Frequency label
                            Text(freq)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                
                // Bass/Treble quick controls
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("BASS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: Binding(
                            get: { (eqBands[0] + eqBands[1] + eqBands[2]) / 3 + 12 },
                            set: { newValue in
                                let adjusted = newValue - 12
                                eqBands[0] = adjusted
                                eqBands[1] = adjusted * 0.8
                                eqBands[2] = adjusted * 0.6
                            }
                        ), in: 0...24)
                        .tint(AppTheme.Colors.primary)
                    }
                    
                    VStack(spacing: 8) {
                        Text("TREBLE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: Binding(
                            get: { (eqBands[7] + eqBands[8] + eqBands[9]) / 3 + 12 },
                            set: { newValue in
                                let adjusted = newValue - 12
                                eqBands[7] = adjusted * 0.6
                                eqBands[8] = adjusted * 0.8
                                eqBands[9] = adjusted
                            }
                        ), in: 0...24)
                        .tint(AppTheme.Colors.primary)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 20)
            .background(Color(.systemBackground))
            .navigationTitle("Equalizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }
    
    private func applyPreset(_ preset: String) {
        switch preset {
        case "Flat": eqBands = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case "Rock": eqBands = [4, 3, -1, -2, 1, 2, 4, 5, 5, 4]
        case "Pop": eqBands = [-1, 2, 4, 4, 1, -1, -2, -2, -1, -1]
        case "Jazz": eqBands = [3, 2, 1, 2, -1, -1, 0, 1, 2, 3]
        case "Classical": eqBands = [4, 3, 2, 1, -1, -2, -1, 2, 3, 4]
        case "Hip-Hop": eqBands = [6, 5, 2, 1, -1, -1, 1, 2, 3, 4]
        case "R&B": eqBands = [4, 4, 2, 1, 0, 1, 2, 3, 3, 2]
        case "Electronic": eqBands = [3, 2, 0, -1, 1, 0, 1, 3, 4, 4]
        case "Bass Boost": eqBands = [8, 6, 4, 2, 0, -1, -2, -3, -3, -3]
        case "Treble Boost": eqBands = [-3, -3, -2, -1, 0, 1, 3, 5, 7, 8]
        default: eqBands = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        }
    }
}

struct ShelfCarouselPage: View {
    let songs: [CatalogSong]
    let startIndex: Int
    var showFlame: Bool = false
    @ObservedObject private var preview = AudioPreviewPlayer.shared
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(songs.enumerated()), id: \.element.id) { localIndex, song in
                let globalIndex = startIndex + localIndex
                let isPlaying = preview.currentTrackId == String(song.id) && preview.isPlaying
                
                Button {
                    if let p = song.previewUrl, let u = URL(string: p) {
                        let id = String(song.id)
                        if preview.currentTrackId == id && preview.isPlaying {
                            preview.pause()
                        } else {
                            preview.play(url: u, trackId: id, title: song.title, artist: song.artist, artworkURL: URL(string: song.artworkUrl ?? ""))
                        }
                        HapticManager.shared.impact(style: .medium)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text("\(globalIndex + 1)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isPlaying ? .red : .secondary)
                            .frame(width: 24)
                        
                        AppAsyncImage(url: URL(string: song.artworkUrl ?? "")) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.15))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .foregroundColor(.gray.opacity(0.4))
                                )
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(song.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(isPlaying ? .red : .primary)
                                .lineLimit(1)
                            Text(song.artist)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if showFlame && globalIndex < 3 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
                .background(
                    ZStack {
                        // 3D shelf base — subtle gradient floor
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                isPlaying
                                    ? Color.red.opacity(0.06)
                                    : Color(.systemBackground)
                            )
                        
                        // Bottom shelf edge — gives the "sitting on a shelf" look
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.black.opacity(0.08),
                                            Color.black.opacity(0.02),
                                            Color.clear
                                        ],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(height: 6)
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 2)
                                )
                        }
                    }
                )
                .overlay(
                    // Shelf divider line
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)
                    }
                )
                .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            }
        }
        .padding(.horizontal, 8)
        // 3D perspective tilt for the whole shelf
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

