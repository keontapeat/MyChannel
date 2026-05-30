// ⚡ PERFORMANCE: Discover, Shazam, Collab playlists extracted from MusicFeaturesAdvanced.swift.
// Compiles independently from the Canvas/Concert/Merch section above line 711.
import SwiftUI

// MARK: - =====================================================
// MARK: - DISCOVER WEEKLY / DAILY MIX
// MARK: - =====================================================

struct DiscoverView: View {
    @State private var selectedMix: MixType = .daily
    
    enum MixType: String, CaseIterable {
        case daily = "Daily Mix"
        case weekly = "Discover Weekly"
        case release = "Release Radar"
        case localMix = "810 Mix"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Featured mix card
                featuredMixCard
                
                // Mix types
                VStack(alignment: .leading, spacing: 16) {
                    Text("Made for You")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(MixType.allCases, id: \.self) { mix in
                                MixCard(mix: mix, isSelected: selectedMix == mix) {
                                    selectedMix = mix
                                    HapticManager.shared.impact(style: .medium)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Today's picks
                VStack(alignment: .leading, spacing: 16) {
                    Text("Today's Picks")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal, 20)
                    
                    LazyVStack(spacing: 0) {
                        ForEach(0..<10) { i in
                            DiscoverTrackRow(index: i + 1)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 20)
        }
        .navigationTitle("For You")
    }
    
    private var featuredMixCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            LinearGradient(
                colors: [.purple, .blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text("DISCOVER WEEKLY")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Your weekly mixtape of fresh music")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Updated every Monday")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 12) {
                    Button {
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Play")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white))
                    }
                    
                    Button {
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
    }
}

struct MixCard: View {
    let mix: DiscoverView.MixType
    let isSelected: Bool
    let action: () -> Void
    
    var gradientColors: [Color] {
        switch mix {
        case .daily: return [.orange, .pink]
        case .weekly: return [.purple, .blue]
        case .release: return [.green, .teal]
        case .localMix: return [.red, .orange]
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 30))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? AppTheme.Colors.primary : .clear, lineWidth: 3)
                )
                
                Text(mix.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                
                Text("Updated daily")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DiscoverTrackRow: View {
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Track \(index)")
                    .font(.system(size: 15))
                Text("Artist Name")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "ellipsis")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - =====================================================
// MARK: - SHAZAM INTEGRATION
// MARK: - =====================================================

struct ShazamView: View {
    @State private var isListening: Bool = false
    @State private var identifiedTrack: ShazamResult? = nil
    @State private var pulseScale: CGFloat = 1.0
    @Environment(\.dismiss) private var dismiss
    
    struct ShazamResult {
        let title: String
        let artist: String
        let artworkURL: String?
        let appleMusicURL: String?
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            mainContent
            resultOverlay
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 30) {
            Spacer()
            shazamButton
            statusText
            Spacer()
            cancelButton
        }
    }
    
    private var shazamButton: some View {
        ZStack {
            pulseRings
            mainListenButton
        }
    }
    
    @ViewBuilder
    private var pulseRings: some View {
        if isListening {
            ForEach(0..<3, id: \.self) { i in
                let scale = pulseScale + CGFloat(i) * 0.2
                let opacity = 1.5 - scale / 2
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .frame(width: 200, height: 200)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
        }
    }
    
    private var mainListenButton: some View {
        Button {
            toggleListening()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 180)
                    .shadow(color: .blue.opacity(0.5), radius: 20)
                
                Image(systemName: "waveform")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var statusText: some View {
        Text(isListening ? "Listening..." : "Tap to identify music")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
    }
    
    private var cancelButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Cancel")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Capsule().fill(.white.opacity(0.1)))
        }
        .padding(.bottom, 40)
    }
    
    @ViewBuilder
    private var resultOverlay: some View {
        if let track = identifiedTrack {
            ShazamResultView(result: track) {
                identifiedTrack = nil
            }
        }
    }
    
    private func toggleListening() {
        isListening.toggle()
        HapticManager.shared.impact(style: .medium)
        
        if isListening {
            // Start pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.5
            }
            
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation {
                    isListening = false
                    pulseScale = 1.0
                    identifiedTrack = ShazamResult(
                        title: "Coochie",
                        artist: "YN Jay",
                        artworkURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg",
                        appleMusicURL: nil
                    )
                }
                HapticManager.shared.notification(type: .success)
            }
        } else {
            pulseScale = 1.0
        }
    }
}

struct ShazamResultView: View {
    let result: ShazamView.ShazamResult
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 20) {
                if let url = result.artworkURL {
                    AsyncImage(url: URL(string: url)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray5))
                    }
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.3), radius: 20)
                }
                
                Text(result.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(result.artist)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 16) {
                    Button {
                        // Open in Apple Music
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Play")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(.white))
                    }
                    
                    Button {
                        // Add to library
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.2)))
                    }
                    
                    Button {
                        // Share
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.2)))
                    }
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 20)
            
            Button {
                onDismiss()
            } label: {
                Text("Close")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 30)
            
            Spacer()
        }
        .background(Color.black.opacity(0.5))
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

// MARK: - =====================================================
// MARK: - COLLABORATIVE PLAYLISTS
// MARK: - =====================================================

struct CollaborativePlaylistView: View {
    @State var playlist: UserPlaylist
    @State private var showInvite: Bool = false
    @StateObject private var playlistService = PlaylistService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Collaborators header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Collaborators")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Button {
                            showInvite = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Invite")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    
                    // Collaborator avatars
                    HStack(spacing: -10) {
                        ForEach(0..<4) { i in
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text("\(["M", "S", "J", "A"][i])")
                                        .font(.system(size: 16, weight: .semibold))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemBackground), lineWidth: 3)
                                )
                        }
                        
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text("+3")
                                    .font(.system(size: 14, weight: .semibold))
                            )
                    }
                    
                    Text("\(7) people can edit this playlist")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Activity feed
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.system(size: 18, weight: .semibold))
                    
                    VStack(spacing: 0) {
                        CollabActivityRow(name: "Mike", action: "added", trackName: "Coochie", time: "2m ago")
                        CollabActivityRow(name: "Sarah", action: "added", trackName: "Flint Flow", time: "1h ago")
                        CollabActivityRow(name: "James", action: "removed", trackName: "Old Song", time: "3h ago")
                    }
                }
                
                // Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Toggle("Allow anyone with link to add songs", isOn: .constant(false))
                        .font(.system(size: 15))
                    
                    Toggle("Notify when songs are added", isOn: .constant(true))
                        .font(.system(size: 15))
                }
            }
            .padding(20)
        }
        .navigationTitle("Collaborate")
        .sheet(isPresented: $showInvite) {
            InviteCollaboratorsSheet()
        }
    }
}

struct CollabActivityRow: View {
    let name: String
    let action: String
    let trackName: String
    let time: String
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.system(size: 14, weight: .semibold))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(name) \(action) \"\(trackName)\"")
                    .font(.system(size: 14))
                Text(time)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

struct InviteCollaboratorsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search friends", text: $searchText)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 20)
                
                // Share link
                VStack(spacing: 12) {
                    Text("Or share invite link")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Button {
                        // Copy link
                        HapticManager.shared.notification(type: .success)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                            Text("Copy Link")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .stroke(AppTheme.Colors.primary, lineWidth: 1.5)
                        )
                    }
                }
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Invite Collaborators")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

