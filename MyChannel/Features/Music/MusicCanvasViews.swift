// ⚡ PERFORMANCE: Canvas views extracted from MusicFeatures.swift.
import SwiftUI
import AVFoundation

//
//  MusicFeatures.swift
//  MyChannel
//
//  Additional Music Features - Downloads, Follow, Settings, Share, etc.
//

import SwiftUI
import Combine

// MARK: - =====================================================
// MARK: - DOWNLOADS / OFFLINE MODE
// MARK: - =====================================================

struct DownloadedTrack: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let artworkURL: String?
    let duration: TimeInterval
    let downloadedAt: Date
    var localFileURL: String?
    let fileSize: Int64 // in bytes
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

@MainActor
final class MusicDownloadManager: ObservableObject {
    static let shared = MusicDownloadManager()
    
    @Published var downloads: [DownloadedTrack] = []
    @Published var downloadingTracks: Set<String> = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var autoDownloadEnabled: Bool = false
    @Published var downloadQuality: AudioQuality = .high
    @Published var downloadOnWiFiOnly: Bool = true
    
    var totalDownloadSize: Int64 {
        downloads.reduce(0) { $0 + $1.fileSize }
    }
    
    var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalDownloadSize)
    }
    
    private init() {
        loadDownloads()
    }
    
    func downloadTrack(_ track: PlaylistTrack) {
        guard !isDownloaded(track.id) else { return }
        downloadingTracks.insert(track.id)
        
        // Simulate download progress
        Task {
            for i in 0...10 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                downloadProgress[track.id] = Double(i) / 10.0
            }
            
            let downloaded = DownloadedTrack(
                id: track.id,
                title: track.title,
                artist: track.artist,
                album: track.album,
                artworkURL: track.artworkURL,
                duration: track.duration,
                downloadedAt: Date(),
                localFileURL: "local://\(track.id).m4a",
                fileSize: Int64.random(in: 3_000_000...8_000_000)
            )
            
            downloads.append(downloaded)
            downloadingTracks.remove(track.id)
            downloadProgress.removeValue(forKey: track.id)
            saveDownloads()
        }
    }
    
    func removeDownload(_ trackId: String) {
        downloads.removeAll { $0.id == trackId }
        saveDownloads()
    }
    
    func isDownloaded(_ trackId: String) -> Bool {
        downloads.contains { $0.id == trackId }
    }
    
    func isDownloading(_ trackId: String) -> Bool {
        downloadingTracks.contains(trackId)
    }
    
    func clearAllDownloads() {
        downloads.removeAll()
        saveDownloads()
    }
    
    private func saveDownloads() {
        if let encoded = try? JSONEncoder().encode(downloads) {
            UserDefaults.standard.set(encoded, forKey: "downloaded_tracks")
        }
    }
    
    private func loadDownloads() {
        if let data = UserDefaults.standard.data(forKey: "downloaded_tracks"),
           let decoded = try? JSONDecoder().decode([DownloadedTrack].self, from: data) {
            downloads = decoded
        }
    }
}

// MARK: - Music Downloads View

struct MusicDownloadsView: View {
    @StateObject private var downloadManager = MusicDownloadManager.shared
    @State private var showDeleteAlert: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Storage info
                storageCard
                
                // Downloads list
                if downloadManager.downloads.isEmpty {
                    emptyState
                } else {
                    downloadsList
                }
            }
            .padding(20)
        }
        .navigationTitle("Downloads")
        .toolbar {
            if !downloadManager.downloads.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear All") {
                        showDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .alert("Clear All Downloads?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                downloadManager.clearAllDownloads()
            }
        } message: {
            Text("This will remove all downloaded songs from your device.")
        }
    }
    
    private var storageCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(downloadManager.downloads.count) songs")
                        .font(.system(size: 20, weight: .bold))
                    Text(downloadManager.formattedTotalSize)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Settings toggles
            Toggle("Download on Wi-Fi only", isOn: $downloadManager.downloadOnWiFiOnly)
                .font(.system(size: 15))
            
            Toggle("Auto-download liked songs", isOn: $downloadManager.autoDownloadEnabled)
                .font(.system(size: 15))
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No downloads yet")
                .font(.system(size: 18, weight: .semibold))
            
            Text("Download songs to listen offline")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.top, 60)
    }
    
    private var downloadsList: some View {
        LazyVStack(spacing: 0) {
            ForEach(downloadManager.downloads) { track in
                DownloadedTrackRow(track: track) {
                    downloadManager.removeDownload(track.id)
                    HapticManager.shared.notification(type: .warning)
                }
            }
        }
    }
}

struct DownloadedTrackRow: View {
    let track: DownloadedTrack
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if let url = track.artworkURL {
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5))
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 15))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(track.formattedSize)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - =====================================================
// MARK: - FOLLOW ARTISTS
// MARK: - =====================================================

@MainActor
final class FollowService: ObservableObject {
    static let shared = FollowService()
    
    @Published var followedArtists: [FollowedArtist] = []
    @Published var newReleases: [NewRelease] = []
    
    struct FollowedArtist: Identifiable, Codable {
        let id: String
        let name: String
        let imageURL: String?
        let followedAt: Date
        var notificationsEnabled: Bool
    }
    
    struct NewRelease: Identifiable, Codable {
        let id: String
        let trackTitle: String
        let artistName: String
        let artistId: String
        let artworkURL: String?
        let releaseDate: Date
        var isNew: Bool
    }
    
    private init() {
        loadFollowedArtists()
    }
    
    func followArtist(id: String, name: String, imageURL: String?) {
        guard !isFollowing(id) else { return }
        let artist = FollowedArtist(
            id: id,
            name: name,
            imageURL: imageURL,
            followedAt: Date(),
            notificationsEnabled: true
        )
        followedArtists.append(artist)
        saveFollowedArtists()
    }
    
    func unfollowArtist(_ id: String) {
        followedArtists.removeAll { $0.id == id }
        saveFollowedArtists()
    }
    
    func isFollowing(_ id: String) -> Bool {
        followedArtists.contains { $0.id == id }
    }
    
    func toggleFollow(id: String, name: String, imageURL: String?) {
        if isFollowing(id) {
            unfollowArtist(id)
        } else {
            followArtist(id: id, name: name, imageURL: imageURL)
        }
    }
    
    func toggleNotifications(for artistId: String) {
        if let index = followedArtists.firstIndex(where: { $0.id == artistId }) {
            followedArtists[index].notificationsEnabled.toggle()
            saveFollowedArtists()
        }
    }
    
    private func saveFollowedArtists() {
        if let encoded = try? JSONEncoder().encode(followedArtists) {
            UserDefaults.standard.set(encoded, forKey: "followed_artists")
        }
    }
    
    private func loadFollowedArtists() {
        if let data = UserDefaults.standard.data(forKey: "followed_artists"),
           let decoded = try? JSONDecoder().decode([FollowedArtist].self, from: data) {
            followedArtists = decoded
        }
    }
}

// MARK: - Following View

struct FollowingView: View {
    @StateObject private var followService = FollowService.shared
    
    var body: some View {
        ScrollView {
            if followService.followedArtists.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Not following anyone yet")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Follow artists to get updates when they release new music")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 100)
                .padding(.horizontal, 40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(followService.followedArtists) { artist in
                        FollowedArtistRow(artist: artist)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("Following")
    }
}

struct FollowedArtistRow: View {
    let artist: FollowService.FollowedArtist
    @StateObject private var followService = FollowService.shared
    
    var body: some View {
        HStack(spacing: 14) {
            if let url = artist.imageURL {
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(.systemGray5))
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "music.mic")
                            .foregroundColor(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.system(size: 16, weight: .semibold))
                Text("Following")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                followService.toggleNotifications(for: artist.id)
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: artist.notificationsEnabled ? "bell.fill" : "bell.slash")
                    .foregroundColor(artist.notificationsEnabled ? AppTheme.Colors.primary : .secondary)
            }
            
            Button {
                followService.unfollowArtist(artist.id)
                HapticManager.shared.impact(style: .medium)
            } label: {
                Text("Following")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - =====================================================
// MARK: - AUDIO QUALITY SETTINGS
// MARK: - =====================================================

enum AudioQuality: String, CaseIterable, Codable {
    case auto = "Auto"
    case low = "Low"
    case normal = "Normal"
    case high = "High"
    case lossless = "Lossless"
    case hiResLossless = "Hi-Res Lossless"
    
    var description: String {
        switch self {
        case .auto: return "Adjusts based on connection"
        case .low: return "64 kbps - Saves data"
        case .normal: return "128 kbps - Standard"
        case .high: return "256 kbps - Best streaming"
        case .lossless: return "ALAC up to 24-bit/48 kHz"
        case .hiResLossless: return "ALAC up to 24-bit/192 kHz"
        }
    }
    
    var dataUsage: String {
        switch self {
        case .auto: return "~1 MB/min"
        case .low: return "~0.5 MB/min"
        case .normal: return "~1 MB/min"
        case .high: return "~2 MB/min"
        case .lossless: return "~6 MB/min"
        case .hiResLossless: return "~12 MB/min"
        }
    }
}

struct AudioSettingsView: View {
    @AppStorage("streaming_quality") private var streamingQuality: AudioQuality = .high
    @AppStorage("download_quality") private var downloadQuality: AudioQuality = .lossless
    @AppStorage("cellular_streaming") private var cellularStreaming: AudioQuality = .normal
    @AppStorage("crossfade_enabled") private var crossfadeEnabled: Bool = false
    @AppStorage("crossfade_duration") private var crossfadeDuration: Double = 3.0
    @AppStorage("gapless_playback") private var gaplessPlayback: Bool = true
    @AppStorage("sound_check") private var soundCheck: Bool = true
    @AppStorage("dolby_atmos") private var dolbyAtmos: Bool = true
    
    var body: some View {
        Form {
            // Streaming Quality
            Section {
                Picker("Wi-Fi Streaming", selection: $streamingQuality) {
                    ForEach(AudioQuality.allCases, id: \.self) { quality in
                        VStack(alignment: .leading) {
                            Text(quality.rawValue)
                            Text(quality.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(quality)
                    }
                }
                
                Picker("Cellular Streaming", selection: $cellularStreaming) {
                    ForEach([AudioQuality.auto, .low, .normal, .high], id: \.self) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
            } header: {
                Text("Streaming")
            } footer: {
                Text("Higher quality uses more data. \(streamingQuality.dataUsage)")
            }
            
            // Download Quality
            Section {
                Picker("Download Quality", selection: $downloadQuality) {
                    ForEach(AudioQuality.allCases, id: \.self) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
            } header: {
                Text("Downloads")
            } footer: {
                Text("Lossless audio requires more storage. \(downloadQuality.dataUsage)")
            }
            
            // Spatial Audio
            Section {
                Toggle("Dolby Atmos", isOn: $dolbyAtmos)
            } header: {
                Text("Spatial Audio")
            } footer: {
                Text("Immersive, multi-dimensional audio on compatible songs.")
            }
            
            // Playback
            Section {
                Toggle("Crossfade", isOn: $crossfadeEnabled)
                
                if crossfadeEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text("\(Int(crossfadeDuration))s")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $crossfadeDuration, in: 1...12, step: 1)
                            .tint(AppTheme.Colors.primary)
                    }
                }
                
                Toggle("Gapless Playback", isOn: $gaplessPlayback)
                Toggle("Sound Check", isOn: $soundCheck)
            } header: {
                Text("Playback")
            } footer: {
                Text("Sound Check automatically adjusts volume to the same level for all songs.")
            }
        }
        .navigationTitle("Audio Quality")
    }
}

// MARK: - =====================================================
// MARK: - SHARE TO STORIES
// MARK: - =====================================================

struct ShareMusicSheet: View {
    let track: PlaylistTrack
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlatform: SharePlatform = .instagram
    @State private var addLyrics: Bool = true
    @State private var showTimestamp: Bool = true
    
    enum SharePlatform: String, CaseIterable {
        case instagram = "Instagram"
        case tiktok = "TikTok"
        case snapchat = "Snapchat"
        case twitter = "Twitter"
        case messages = "Messages"
        case copy = "Copy Link"
        
        var icon: String {
            switch self {
            case .instagram: return "camera.fill"
            case .tiktok: return "music.note"
            case .snapchat: return "bolt.fill"
            case .twitter: return "bubble.left.fill"
            case .messages: return "message.fill"
            case .copy: return "link"
            }
        }
        
        var color: Color {
            switch self {
            case .instagram: return .pink
            case .tiktok: return .black
            case .snapchat: return .yellow
            case .twitter: return .blue
            case .messages: return .green
            case .copy: return .gray
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preview card
                sharePreviewCard
                
                // Options
                VStack(spacing: 12) {
                    Toggle("Add lyrics snippet", isOn: $addLyrics)
                    Toggle("Show timestamp", isOn: $showTimestamp)
                }
                .padding(.horizontal, 20)
                
                // Share platforms
                VStack(alignment: .leading, spacing: 12) {
                    Text("Share to")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(SharePlatform.allCases, id: \.self) { platform in
                                SharePlatformButton(
                                    platform: platform,
                                    isSelected: selectedPlatform == platform
                                ) {
                                    selectedPlatform = platform
                                    HapticManager.shared.impact(style: .light)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
                
                // Share button
                Button {
                    shareToSelectedPlatform()
                    HapticManager.shared.notification(type: .success)
                    dismiss()
                } label: {
                    Text("Share to \(selectedPlatform.rawValue)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var sharePreviewCard: some View {
        ZStack {
            // Background
            if let url = track.artworkURL {
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray
                }
                .blur(radius: 30)
            }
            
            Color.black.opacity(0.4)
            
            VStack(spacing: 12) {
                if let url = track.artworkURL {
                    AsyncImage(url: URL(string: url)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray)
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 10)
                }
                
                Text(track.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text(track.artist)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                
                if addLyrics {
                    Text("\"This that 810 life...\"")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .italic()
                        .padding(.top, 8)
                }
            }
            .padding(24)
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private func shareToSelectedPlatform() {
        // Implement actual sharing logic
    }
}

struct SharePlatformButton: View {
    let platform: ShareMusicSheet.SharePlatform
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(platform.color)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: platform.icon)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 3)
                )
                
                Text(platform.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - =====================================================
// MARK: - SONG CREDITS
// MARK: - =====================================================

struct SongCredits: Identifiable {
    let id: String
    let trackTitle: String
    let artist: String
    let album: String
    let releaseDate: Date
    let writers: [String]
    let producers: [String]
    let featuredArtists: [String]
    let label: String
    let isrc: String
    let copyright: String
    
    static let sample = SongCredits(
        id: "1",
        trackTitle: "Coochie",
        artist: "YN Jay",
        album: "Coochie Chronicles",
        releaseDate: Date(),
        writers: ["Justin Harris", "YN Jay"],
        producers: ["Enrgy Beats", "Helluva"],
        featuredArtists: [],
        label: "Empire",
        isrc: "USRC12345678",
        copyright: "℗ 2023 Empire Distribution"
    )
}

struct SongCreditsView: View {
    let credits: SongCredits
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(credits.trackTitle)
                            .font(.system(size: 28, weight: .bold))
                        Text(credits.artist)
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Writers
                    creditSection(title: "Written By", items: credits.writers)
                    
                    // Producers
                    creditSection(title: "Produced By", items: credits.producers)
                    
                    // Featured Artists
                    if !credits.featuredArtists.isEmpty {
                        creditSection(title: "Featuring", items: credits.featuredArtists)
                    }
                    
                    Divider()
                    
                    // Album info
                    VStack(alignment: .leading, spacing: 12) {
                        infoRow(label: "Album", value: credits.album)
                        infoRow(label: "Release Date", value: formatDate(credits.releaseDate))
                        infoRow(label: "Label", value: credits.label)
                        infoRow(label: "ISRC", value: credits.isrc)
                    }
                    
                    // Copyright
                    Text(credits.copyright)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.top, 12)
                }
                .padding(20)
            }
            .navigationTitle("Credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func creditSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 16, weight: .medium))
            }
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - =====================================================
// MARK: - FRIEND ACTIVITY
// MARK: - =====================================================

struct FriendActivity: Identifiable {
    let id: String
    let userName: String
    let userImageURL: String?
    let trackTitle: String
    let artistName: String
    let trackArtworkURL: String?
    let timestamp: Date
    var isPlaying: Bool
}

struct FriendActivityView: View {
    @State private var activities: [FriendActivity] = [
        FriendActivity(id: "1", userName: "Mike", userImageURL: nil, trackTitle: "Coochie", artistName: "YN Jay", trackArtworkURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg", timestamp: Date(), isPlaying: true),
        FriendActivity(id: "2", userName: "Sarah", userImageURL: nil, trackTitle: "Flint Flow", artistName: "Rio Da Yung OG", trackArtworkURL: "https://i.ytimg.com/vi/6DZSh9vqlWc/hqdefault.jpg", timestamp: Date().addingTimeInterval(-300), isPlaying: false),
        FriendActivity(id: "3", userName: "James", userImageURL: nil, trackTitle: "Enbarassing", artistName: "RMC Mike", trackArtworkURL: "https://i.ytimg.com/vi/x_E1bq1sYdY/hqdefault.jpg", timestamp: Date().addingTimeInterval(-1800), isPlaying: true)
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(activities) { activity in
                    FriendActivityRow(activity: activity)
                }
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("Friend Activity")
    }
}

struct FriendActivityRow: View {
    let activity: FriendActivity
    
    var body: some View {
        HStack(spacing: 12) {
            // User avatar
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(activity.userName.prefix(1)))
                            .font(.system(size: 18, weight: .semibold))
                    )
                
                if activity.isPlaying {
                    Circle()
                        .fill(.green)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.userName)
                    .font(.system(size: 15, weight: .semibold))
                
                HStack(spacing: 4) {
                    if activity.isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                    Text("\(activity.trackTitle) • \(activity.artistName)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let url = activity.trackArtworkURL {
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5))
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - =====================================================
// MARK: - SONG RADIO
// MARK: - =====================================================

struct SongRadioView: View {
    let seedTrack: PlaylistTrack
    @State private var radioTracks: [CatalogSong] = []
    @State private var isLoading: Bool = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Creating your radio station...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header
                            VStack(spacing: 12) {
                                if let url = seedTrack.artworkURL {
                                    AsyncImage(url: URL(string: url)) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5))
                                    }
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
                                Text("\(seedTrack.title) Radio")
                                    .font(.system(size: 20, weight: .bold))
                                
                                Text("Based on \(seedTrack.title) by \(seedTrack.artist)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 20)
                            
                            // Play button
                            Button {
                                HapticManager.shared.impact(style: .medium)
                            } label: {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Play Radio")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(AppTheme.Colors.primary)
                                .clipShape(Capsule())
                            }
                            
                            // Track list
                            LazyVStack(spacing: 0) {
                                ForEach(radioTracks, id: \.id) { track in
                                    RadioTrackRow(track: track)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .navigationTitle("Radio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadRadioTracks()
            }
        }
    }
    
    private func loadRadioTracks() async {
        // Search for similar tracks
        if let results = try? await MusicCatalogService.shared.searchSongs(term: seedTrack.artist, limit: 20) {
            radioTracks = results
        }
        isLoading = false
    }
}

struct RadioTrackRow: View {
    let track: CatalogSong
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: track.artworkUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5))
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 15))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "ellipsis")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - =====================================================
// MARK: - RELEASE RADAR
// MARK: - =====================================================

struct ReleaseRadarView: View {
    @StateObject private var followService = FollowService.shared
    @State private var releases: [FollowService.NewRelease] = []
    
    var body: some View {
        ScrollView {
            if releases.isEmpty && followService.followedArtists.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No new releases")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Follow artists to see their new releases here")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 100)
                .padding(.horizontal, 40)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    Text("New releases from artists you follow")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                    
                    LazyVStack(spacing: 0) {
                        ForEach(releases) { release in
                            ReleaseRow(release: release)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)
            }
        }
        .navigationTitle("Release Radar")
    }
}

struct ReleaseRow: View {
    let release: FollowService.NewRelease
    
    var body: some View {
        HStack(spacing: 12) {
            if let url = release.artworkURL {
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(release.trackTitle)
                        .font(.system(size: 16, weight: .semibold))
                    if release.isNew {
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.red))
                    }
                }
                Text(release.artistName)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                HapticManager.shared.impact(style: .medium)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - =====================================================
// MARK: - KARAOKE MODE
// MARK: - =====================================================

struct KaraokeModeView: View {
    let track: PlaylistTrack
    @State private var vocalLevel: Double = 0.2 // 0 = no vocals, 1 = full vocals
    @State private var isPlaying: Bool = false
    @State private var currentLyricIndex: Int = 0
    @Environment(\.dismiss) private var dismiss
    
    let sampleLyrics: [String] = [
        "Yeah, yeah",
        "Flint city, 810",
        "We came from nothing",
        "Now we running everything",
        "Shout out to the whole gang",
        "We been grinding all day"
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Close button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    
                    Text("KARAOKE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(2)
                    
                    Spacer()
                    
                    Button {
                        // Settings
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Lyrics display
                VStack(spacing: 16) {
                    ForEach(Array(sampleLyrics.enumerated()), id: \.offset) { index, lyric in
                        Text(lyric)
                            .font(.system(size: index == currentLyricIndex ? 32 : 24, weight: .bold))
                            .foregroundColor(index == currentLyricIndex ? .white : .white.opacity(0.3))
                            .scaleEffect(index == currentLyricIndex ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3), value: currentLyricIndex)
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Vocal control
                VStack(spacing: 16) {
                    Text("Vocal Level")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    HStack(spacing: 16) {
                        Image(systemName: "mic.slash.fill")
                            .foregroundColor(.white.opacity(0.5))
                        
                        Slider(value: $vocalLevel, in: 0...1)
                            .tint(.white)
                        
                        Image(systemName: "mic.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 30)
                }
                
                // Play button
                Button {
                    isPlaying.toggle()
                    if isPlaying {
                        startKaraoke()
                    }
                    HapticManager.shared.impact(style: .medium)
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private func startKaraoke() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
            if !isPlaying {
                timer.invalidate()
                return
            }
            withAnimation {
                currentLyricIndex = (currentLyricIndex + 1) % sampleLyrics.count
            }
        }
    }
}

