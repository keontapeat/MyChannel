//
//  FlintArtistsSection.swift
//  MyChannel
//
//  🔥🔥🔥 FLINT ARTISTS SECTION - 810 REPRESENT! 🔥🔥🔥
//  Premium UI component showcasing Flint, MI artists
//  - Pinned at TOP of MusicHub
//  - 810 verified badge
//  - Fire styling and animations
//  - Support local CTA
//

import SwiftUI

// MARK: - Flint Artists Section (Main Component)

struct FlintArtistsSection: View {
    @StateObject private var flintService = FlintArtistService.shared
    @StateObject private var musicKitService = MusicKitService.shared
    @State private var selectedArtist: FlintArtist?
    @State private var showArtistDetail: Bool = false
    @State private var isExpanded: Bool = false
    @State private var animateHeader: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with 810 badge
            sectionHeader
            
            // Featured artists carousel
            if flintService.isLoading {
                loadingView
            } else if flintService.featuredArtists.isEmpty && flintService.artists.isEmpty {
                emptyStateView
            } else {
                artistsCarousel
            }
            
            // Rising artists row (if expanded)
            if isExpanded && !flintService.risingArtists.isEmpty {
                risingArtistsRow
            }
        }
        .padding(.vertical, 16)
        .background(flintGradientBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateHeader = true
            }
            Task {
                await flintService.fetchArtists()
            }
        }
        .sheet(isPresented: $showArtistDetail) {
            if let artist = selectedArtist {
                FlintArtistDetailSheet(artist: artist)
            }
        }
    }
    
    // MARK: - Section Header
    
    private var sectionHeader: some View {
        HStack(spacing: 12) {
            // 810 Badge
            badge810
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Flint Artists")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Support local talent from the 810")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Expand/collapse button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 16)
        .scaleEffect(animateHeader ? 1.0 : 0.95)
        .opacity(animateHeader ? 1.0 : 0.0)
    }
    
    // MARK: - 810 Badge
    
    private var badge810: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.orange.opacity(0.6), .red.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .blur(radius: 8)
            
            // Badge background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .shadow(color: .orange.opacity(0.5), radius: 8, x: 0, y: 4)
            
            // 810 text
            Text("810")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Artists Carousel
    
    private var artistsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(displayArtists) { artist in
                    FlintArtistCard(artist: artist) {
                        selectedArtist = artist
                        showArtistDetail = true
                        HapticManager.shared.impact(style: .medium)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var displayArtists: [FlintArtist] {
        if flintService.featuredArtists.isEmpty {
            return flintService.artists
        }
        return flintService.featuredArtists
    }
    
    // MARK: - Rising Artists Row
    
    private var risingArtistsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.green)
                Text("Rising Artists")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(flintService.risingArtists) { artist in
                        FlintArtistMiniCard(artist: artist) {
                            selectedArtist = artist
                            showArtistDetail = true
                            HapticManager.shared.impact(style: .light)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        HStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 140, height: 180)
                    .shimmering()
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.mic")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No artists yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Be the first to register!")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Background
    
    private var flintGradientBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.15, green: 0.15, blue: 0.2),
                Color(red: 0.1, green: 0.1, blue: 0.15),
                Color(red: 0.08, green: 0.08, blue: 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            // Subtle fire gradient overlay
            LinearGradient(
                colors: [
                    .orange.opacity(0.15),
                    .red.opacity(0.1),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Flint Artist Card

struct FlintArtistCard: View {
    let artist: FlintArtist
    let onTap: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Artist image
                artistImage
                
                // Artist info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(artist.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if artist.isVerified {
                            verificationBadge
                        }
                    }
                    
                    Text(artist.genres.prefix(2).joined(separator: " • "))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                    
                    // Stats
                    HStack(spacing: 8) {
                        Label("\(formatNumber(artist.monthlyListeners))", systemImage: "headphones")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .frame(width: 140)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    private var artistImage: some View {
        ZStack {
            if let imageURL = artist.profileImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    artistPlaceholder
                }
            } else {
                artistPlaceholder
            }
        }
        .frame(width: 116, height: 116)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            // 810 mini badge
            Text("810")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .padding(6),
            alignment: .topTrailing
        )
    }
    
    private var artistPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [.gray.opacity(0.3), .gray.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Image(systemName: "music.mic")
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    private var verificationBadge: some View {
        Image(systemName: artist.verificationBadge.icon)
            .font(.system(size: 12))
            .foregroundColor(artist.verificationBadge.color)
    }
    
    private func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000)
        }
        return "\(num)"
    }
}

// MARK: - Flint Artist Mini Card (for Rising Artists)

struct FlintArtistMiniCard: View {
    let artist: FlintArtist
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Mini profile image
                ZStack {
                    if let imageURL = artist.profileImageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "music.mic")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.green.opacity(0.5), lineWidth: 2)
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(artist.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("Rising")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Flint Artist Detail Sheet

struct FlintArtistDetailSheet: View {
    let artist: FlintArtist
    @Environment(\.dismiss) private var dismiss
    @StateObject private var flintService = FlintArtistService.shared
    @StateObject private var musicKitService = MusicKitService.shared
    @State private var tracks: [FlintArtistTrack] = []
    @State private var isLoadingTracks: Bool = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with banner and profile
                    artistHeader
                    
                    // Stats row
                    statsRow
                    
                    // Bio
                    if let bio = artist.bio {
                        bioSection(bio)
                    }
                    
                    // Tracks
                    tracksSection
                    
                    // Social links
                    socialLinksSection
                    
                    // Support CTA
                    supportCTA
                }
                .padding(.bottom, 40)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(artist.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .task {
            tracks = await flintService.getArtistTracks(artist: artist)
            isLoadingTracks = false
        }
    }
    
    // MARK: - Artist Header
    
    private var artistHeader: some View {
        ZStack(alignment: .bottom) {
            // Banner gradient
            LinearGradient(
                colors: [.orange.opacity(0.6), .red.opacity(0.4), Color(uiColor: .systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            
            // Profile image
            VStack(spacing: 12) {
                ZStack {
                    if let imageURL = artist.profileImageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "music.mic")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // Name and badge
                HStack(spacing: 8) {
                    Text(artist.displayName)
                        .font(.system(size: 24, weight: .bold))
                    
                    if artist.isVerified {
                        HStack(spacing: 4) {
                            Text("810")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.orange, .red],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                            
                            Image(systemName: artist.verificationBadge.icon)
                                .foregroundColor(artist.verificationBadge.color)
                        }
                    }
                }
                
                Text(artist.genres.joined(separator: " • "))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .offset(y: 60)
        }
        .padding(.bottom, 60)
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: artist.monthlyListeners, label: "Monthly Listeners")
            Divider().frame(height: 40)
            statItem(value: artist.totalStreams, label: "Total Streams")
            Divider().frame(height: 40)
            statItem(value: artist.followerCount, label: "Followers")
        }
        .padding(.horizontal, 20)
    }
    
    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(formatNumber(value))
                .font(.system(size: 20, weight: .bold))
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Bio Section
    
    private func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.system(size: 18, weight: .bold))
            Text(bio)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Tracks Section
    
    private var tracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Tracks")
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 20)
            
            if isLoadingTracks {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if tracks.isEmpty {
                Text("No tracks available on Apple Music")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(tracks.prefix(5)) { flintTrack in
                        FlintTrackRow(track: flintTrack.track, artist: artist)
                    }
                }
            }
        }
    }
    
    // MARK: - Social Links
    
    private var socialLinksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect")
                .font(.system(size: 18, weight: .bold))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if let instagram = artist.instagramHandle {
                        socialButton(icon: "camera.fill", label: "@\(instagram)", color: .pink)
                    }
                    if let twitter = artist.twitterHandle {
                        socialButton(icon: "at", label: "@\(twitter)", color: .blue)
                    }
                    if artist.spotifyArtistID != nil {
                        socialButton(icon: "music.note", label: "Spotify", color: .green)
                    }
                    if artist.appleMusicURL != nil {
                        socialButton(icon: "applelogo", label: "Apple Music", color: .red)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func socialButton(icon: String, label: String, color: Color) -> some View {
        Button {
            HapticManager.shared.impact(style: .light)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color)
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Support CTA
    
    private var supportCTA: some View {
        VStack(spacing: 12) {
            Text("Support \(artist.displayName)")
                .font(.system(size: 18, weight: .bold))
            
            Text("Show love to local Flint talent")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Button {
                HapticManager.shared.impact(style: .medium)
                // TODO: Implement tip flow
            } label: {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("Send a Tip")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .padding(.horizontal, 20)
    }
    
    private func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000)
        }
        return "\(num)"
    }
}

// MARK: - Flint Track Row

struct FlintTrackRow: View {
    let track: MusicKitTrack
    let artist: FlintArtist
    @StateObject private var musicKitService = MusicKitService.shared
    @StateObject private var storeKit = StoreKitService.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artworkURL = track.artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                    
                    // 810 badge
                    Text("810")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                
                Text(track.artistName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Play button
            Button {
                Task {
                    do {
                        try await musicKitService.play(track: track)
                        // Record stream for Flint artist
                        await FlintArtistService.shared.recordStream(artistID: artist.id)
                    } catch {
                        print("❌ Playback error: \(error)")
                    }
                }
                HapticManager.shared.impact(style: .medium)
            } label: {
                Image(systemName: musicKitService.currentTrack?.id == track.id && musicKitService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Shimmer Effect
// Note: Uses ShimmerModifier from SharedModels.swift

extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }
}

// MARK: - Preview

#if DEBUG
struct FlintArtistsSection_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            FlintArtistsSection()
        }
        .background(Color(uiColor: .systemBackground))
    }
}
#endif


