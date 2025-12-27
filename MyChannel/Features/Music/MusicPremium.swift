//
//  MusicPremium.swift
//  MyChannel
//
//  Premium Music Features - Podcasts, Party Mode, Stems, Focus, Workout, etc.
//

import SwiftUI
import Combine

// MARK: - =====================================================
// MARK: - PODCAST INTEGRATION
// MARK: - =====================================================

struct Podcast: Identifiable {
    let id: String
    let title: String
    let author: String
    let artworkURL: String?
    let description: String
    let category: String
    let episodeCount: Int
    var isSubscribed: Bool
    let isExplicit: Bool
}

struct PodcastEpisode: Identifiable {
    let id: String
    let title: String
    let description: String
    let duration: TimeInterval
    let publishedDate: Date
    let artworkURL: String?
    let audioURL: String
    var playbackProgress: Double // 0.0 - 1.0
    var isDownloaded: Bool
}

@MainActor
final class PodcastService: ObservableObject {
    static let shared = PodcastService()
    
    @Published var subscribedPodcasts: [Podcast] = []
    @Published var trendingPodcasts: [Podcast] = []
    @Published var recentEpisodes: [PodcastEpisode] = []
    @Published var downloadedEpisodes: [PodcastEpisode] = []
    @Published var playbackQueue: [PodcastEpisode] = []
    
    private init() {
        loadSampleData()
    }
    
    private func loadSampleData() {
        trendingPodcasts = [
            Podcast(id: "1", title: "The Flint Perspective", author: "810 Media", artworkURL: nil, description: "Stories from the heart of Flint", category: "Culture", episodeCount: 45, isSubscribed: false, isExplicit: false),
            Podcast(id: "2", title: "Behind the Bars", author: "YN Jay", artworkURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg", description: "Breaking down the hottest verses", category: "Music", episodeCount: 28, isSubscribed: true, isExplicit: true),
            Podcast(id: "3", title: "810 Uncensored", author: "Flint Legends", artworkURL: nil, description: "Raw conversations with Flint artists", category: "Music", episodeCount: 67, isSubscribed: false, isExplicit: true),
            Podcast(id: "4", title: "Grind Talk", author: "Rio Da Yung OG", artworkURL: "https://i.ytimg.com/vi/6DZSh9vqlWc/hqdefault.jpg", description: "Entrepreneurship and hustle mentality", category: "Business", episodeCount: 32, isSubscribed: true, isExplicit: true),
            Podcast(id: "5", title: "Michigan Music History", author: "Detroit Sound", artworkURL: nil, description: "The evolution of Michigan hip-hop", category: "Music", episodeCount: 89, isSubscribed: false, isExplicit: false)
        ]
        
        subscribedPodcasts = trendingPodcasts.filter { $0.isSubscribed }
        
        recentEpisodes = [
            PodcastEpisode(id: "e1", title: "How Flint Changed Hip-Hop", description: "The unique sound of the 810", duration: 3600, publishedDate: Date(), artworkURL: nil, audioURL: "", playbackProgress: 0.3, isDownloaded: false),
            PodcastEpisode(id: "e2", title: "Interview with YN Jay", description: "Exclusive conversation", duration: 4500, publishedDate: Date().addingTimeInterval(-86400), artworkURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg", audioURL: "", playbackProgress: 0, isDownloaded: true),
            PodcastEpisode(id: "e3", title: "Making It Out", description: "Stories of success from Flint", duration: 2700, publishedDate: Date().addingTimeInterval(-172800), artworkURL: nil, audioURL: "", playbackProgress: 1.0, isDownloaded: false)
        ]
    }
    
    func subscribe(to podcast: Podcast) {
        if let index = trendingPodcasts.firstIndex(where: { $0.id == podcast.id }) {
            trendingPodcasts[index].isSubscribed = true
            subscribedPodcasts = trendingPodcasts.filter { $0.isSubscribed }
        }
    }
    
    func unsubscribe(from podcast: Podcast) {
        if let index = trendingPodcasts.firstIndex(where: { $0.id == podcast.id }) {
            trendingPodcasts[index].isSubscribed = false
            subscribedPodcasts = trendingPodcasts.filter { $0.isSubscribed }
        }
    }
}

struct PodcastsView: View {
    @StateObject private var podcastService = PodcastService.shared
    @State private var selectedTab: PodcastTab = .forYou
    
    enum PodcastTab: String, CaseIterable {
        case forYou = "For You"
        case browse = "Browse"
        case library = "Library"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(PodcastTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                selectedTab == tab ? 
                                    Color(.systemGray5).clipShape(RoundedRectangle(cornerRadius: 8)) : 
                                    Color.clear.clipShape(RoundedRectangle(cornerRadius: 8))
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            ScrollView {
                switch selectedTab {
                case .forYou:
                    podcastForYouContent
                case .browse:
                    podcastBrowseContent
                case .library:
                    podcastLibraryContent
                }
            }
        }
        .navigationTitle("Podcasts")
    }
    
    private var podcastForYouContent: some View {
        VStack(spacing: 24) {
            // Continue listening
            if !podcastService.recentEpisodes.filter({ $0.playbackProgress > 0 && $0.playbackProgress < 1 }).isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Continue Listening")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(podcastService.recentEpisodes.filter { $0.playbackProgress > 0 && $0.playbackProgress < 1 }) { episode in
                                ContinueEpisodeCard(episode: episode)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            
            // New episodes
            VStack(alignment: .leading, spacing: 12) {
                Text("New Episodes")
                    .font(.system(size: 22, weight: .bold))
                    .padding(.horizontal, 20)
                
                LazyVStack(spacing: 0) {
                    ForEach(podcastService.recentEpisodes) { episode in
                        EpisodeRow(episode: episode)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Trending podcasts
            VStack(alignment: .leading, spacing: 12) {
                Text("Trending")
                    .font(.system(size: 22, weight: .bold))
                    .padding(.horizontal, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(podcastService.trendingPodcasts) { podcast in
                            PodcastCard(podcast: podcast)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.top, 20)
    }
    
    private var podcastBrowseContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Categories
            VStack(alignment: .leading, spacing: 12) {
                Text("Categories")
                    .font(.system(size: 22, weight: .bold))
                    .padding(.horizontal, 20)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    PodcastCategoryCard(name: "Music", icon: "music.note", color: .red)
                    PodcastCategoryCard(name: "Culture", icon: "globe", color: .purple)
                    PodcastCategoryCard(name: "Business", icon: "briefcase.fill", color: .blue)
                    PodcastCategoryCard(name: "Comedy", icon: "face.smiling", color: .yellow)
                    PodcastCategoryCard(name: "Sports", icon: "sportscourt.fill", color: .green)
                    PodcastCategoryCard(name: "True Crime", icon: "magnifyingglass", color: .orange)
                }
                .padding(.horizontal, 20)
            }
            
            // All podcasts
            VStack(alignment: .leading, spacing: 12) {
                Text("All Shows")
                    .font(.system(size: 22, weight: .bold))
                    .padding(.horizontal, 20)
                
                LazyVStack(spacing: 0) {
                    ForEach(podcastService.trendingPodcasts) { podcast in
                        PodcastRow(podcast: podcast)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 20)
    }
    
    private var podcastLibraryContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if podcastService.subscribedPodcasts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No subscriptions yet")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Subscribe to podcasts to see them here")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Shows")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal, 20)
                    
                    LazyVStack(spacing: 0) {
                        ForEach(podcastService.subscribedPodcasts) { podcast in
                            PodcastRow(podcast: podcast)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Downloaded
                if !podcastService.downloadedEpisodes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Downloaded")
                            .font(.system(size: 22, weight: .bold))
                            .padding(.horizontal, 20)
                        
                        LazyVStack(spacing: 0) {
                            ForEach(podcastService.downloadedEpisodes) { episode in
                                EpisodeRow(episode: episode)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .padding(.top, 20)
    }
}

struct PodcastCard: View {
    let podcast: Podcast
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let url = podcast.artworkURL {
                    AsyncImage(url: URL(string: url)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        podcastPlaceholder
                    }
                } else {
                    podcastPlaceholder
                }
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Text(podcast.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            
            Text(podcast.author)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140)
    }
    
    private var podcastPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "mic.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.7))
            )
    }
}

struct PodcastRow: View {
    let podcast: Podcast
    @StateObject private var podcastService = PodcastService.shared
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if let url = podcast.artworkURL {
                    AsyncImage(url: URL(string: url)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(
                            Image(systemName: "mic.fill")
                                .foregroundColor(.white.opacity(0.7))
                        )
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(podcast.title)
                        .font(.system(size: 15, weight: .semibold))
                    if podcast.isExplicit {
                        Text("E")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(2)
                            .background(RoundedRectangle(cornerRadius: 2).stroke(Color.secondary, lineWidth: 1))
                    }
                }
                Text(podcast.author)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text("\(podcast.episodeCount) episodes")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                if podcast.isSubscribed {
                    podcastService.unsubscribe(from: podcast)
                } else {
                    podcastService.subscribe(to: podcast)
                }
                HapticManager.shared.impact(style: .medium)
            } label: {
                Text(podcast.isSubscribed ? "Subscribed" : "Subscribe")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(podcast.isSubscribed ? .secondary : AppTheme.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(podcast.isSubscribed ? Color(.systemGray5) : AppTheme.Colors.primary.opacity(0.15))
                    )
            }
        }
        .padding(.vertical, 10)
    }
}

struct EpisodeRow: View {
    let episode: PodcastEpisode
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let url = episode.artworkURL {
                    AsyncImage(url: URL(string: url)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray5))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "mic.fill")
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(formatDuration(episode.duration))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    if episode.isDownloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                    
                    if episode.playbackProgress > 0 && episode.playbackProgress < 1 {
                        Text("\(Int(episode.playbackProgress * 100))% played")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else if episode.playbackProgress >= 1 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
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
        .padding(.vertical, 10)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        }
        return "\(minutes) min"
    }
}

struct ContinueEpisodeCard: View {
    let episode: PodcastEpisode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottom) {
                if let url = episode.artworkURL {
                    AsyncImage(url: URL(string: url)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray5))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                
                // Progress bar
                GeometryReader { geo in
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(height: 3)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: geo.size.width * episode.playbackProgress)
                            }
                    }
                }
            }
            .frame(width: 160, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Text(episode.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
            
            Text("\(Int((1 - episode.playbackProgress) * episode.duration / 60)) min left")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(width: 160)
    }
}

struct PodcastCategoryCard: View {
    let name: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(name)
                .font(.system(size: 15, weight: .semibold))
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - =====================================================
// MARK: - PARTY MODE (Listen Together)
// MARK: - =====================================================

struct PartySession: Identifiable {
    let id: String
    let hostName: String
    let hostImageURL: String?
    var currentTrack: PartyTrack?
    var listeners: [PartyListener]
    let createdAt: Date
    var isActive: Bool
}

struct PartyTrack {
    let title: String
    let artist: String
    let artworkURL: String?
    let progress: Double
    let duration: TimeInterval
}

struct PartyListener: Identifiable {
    let id: String
    let name: String
    let imageURL: String?
    var isHost: Bool
    var canQueue: Bool
}

struct PartyModeView: View {
    @State private var isHosting: Bool = false
    @State private var activeSession: PartySession? = nil
    @State private var inviteLink: String = ""
    @State private var showInvite: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let session = activeSession {
                    activePartyView(session: session)
                } else {
                    startPartyView
                }
            }
            .navigationTitle("Party Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var startPartyView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Party illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.purple)
            }
            
            VStack(spacing: 12) {
                Text("Listen Together")
                    .font(.system(size: 28, weight: .bold))
                
                Text("Start a party and invite friends to listen to music in sync, no matter where they are.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    startParty()
                    HapticManager.shared.impact(style: .medium)
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start a Party")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                
                Button {
                    // Join with code
                } label: {
                    Text("Join with Code")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.purple.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }
    
    private func activePartyView(session: PartySession) -> some View {
        VStack(spacing: 20) {
            // Now playing
            if let track = session.currentTrack {
                VStack(spacing: 16) {
                    if let url = track.artworkURL {
                        AsyncImage(url: URL(string: url)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray5))
                        }
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.3), radius: 20)
                    }
                    
                    Text(track.title)
                        .font(.system(size: 20, weight: .bold))
                    
                    Text(track.artist)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    // Progress
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray4))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(AppTheme.Colors.primary)
                                        .frame(width: geo.size.width * track.progress)
                                }
                        }
                        .frame(height: 4)
                        
                        HStack {
                            Text(formatTime(track.duration * track.progress))
                            Spacer()
                            Text(formatTime(track.duration))
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Listeners
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Listening (\(session.listeners.count))")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Button {
                        showInvite = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Invite")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.purple)
                    }
                }
                .padding(.horizontal, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(session.listeners) { listener in
                            VStack(spacing: 6) {
                                ZStack(alignment: .bottomTrailing) {
                                    Circle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Text(String(listener.name.prefix(1)))
                                                .font(.system(size: 20, weight: .semibold))
                                        )
                                    
                                    if listener.isHost {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.yellow)
                                            .background(Circle().fill(Color(.systemBackground)).frame(width: 18, height: 18))
                                    }
                                }
                                
                                Text(listener.name)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                            }
                            .frame(width: 60)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            Spacer()
            
            // Controls (host only)
            if isHosting {
                HStack(spacing: 30) {
                    Button {
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 28))
                    }
                    
                    Button {
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 60))
                    }
                    
                    Button {
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 28))
                    }
                }
                .foregroundColor(.primary)
            }
            
            // Leave/End button
            Button {
                activeSession = nil
                isHosting = false
                HapticManager.shared.notification(type: .warning)
            } label: {
                Text(isHosting ? "End Party" : "Leave Party")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private func startParty() {
        isHosting = true
        activeSession = PartySession(
            id: UUID().uuidString,
            hostName: "You",
            hostImageURL: nil,
            currentTrack: PartyTrack(
                title: "Coochie",
                artist: "YN Jay",
                artworkURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg",
                progress: 0.35,
                duration: 180
            ),
            listeners: [
                PartyListener(id: "1", name: "You", imageURL: nil, isHost: true, canQueue: true),
                PartyListener(id: "2", name: "Mike", imageURL: nil, isHost: false, canQueue: true),
                PartyListener(id: "3", name: "Sarah", imageURL: nil, isHost: false, canQueue: true)
            ],
            createdAt: Date(),
            isActive: true
        )
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - =====================================================
// MARK: - STEM SEPARATION (Vocals/Drums/Bass/Melody)
// MARK: - =====================================================

struct StemPlayerView: View {
    let trackTitle: String
    let artistName: String
    let artworkURL: String?
    
    @State private var vocalsLevel: Double = 1.0
    @State private var drumsLevel: Double = 1.0
    @State private var bassLevel: Double = 1.0
    @State private var otherLevel: Double = 1.0
    @State private var isPlaying: Bool = false
    @State private var isProcessing: Bool = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            if isProcessing {
                processingView
            } else {
                stemControlsView
            }
        }
        .onAppear {
            // Simulate AI processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    isProcessing = false
                }
            }
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 24) {
            // Artwork
            if let url = artworkURL {
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray5))
                }
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            VStack(spacing: 8) {
                Text("Separating Stems...")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Using AI to extract vocals, drums, bass, and melody")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
        }
        .padding(40)
    }
    
    private var stemControlsView: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("STEM PLAYER")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                Button {
                    // Export stems
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            
            // Track info
            VStack(spacing: 8) {
                if let url = artworkURL {
                    AsyncImage(url: URL(string: url)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5))
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Text(trackTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text(artistName)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Stem controls
            VStack(spacing: 20) {
                StemSlider(name: "Vocals", icon: "mic.fill", level: $vocalsLevel, color: .red)
                StemSlider(name: "Drums", icon: "drum.fill", level: $drumsLevel, color: .orange)
                StemSlider(name: "Bass", icon: "speaker.wave.3.fill", level: $bassLevel, color: .blue)
                StemSlider(name: "Other", icon: "music.note", level: $otherLevel, color: .green)
            }
            .padding(.horizontal, 20)
            
            // Quick presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    StemPresetButton(name: "Full Mix") {
                        withAnimation {
                            vocalsLevel = 1.0
                            drumsLevel = 1.0
                            bassLevel = 1.0
                            otherLevel = 1.0
                        }
                    }
                    StemPresetButton(name: "Instrumental") {
                        withAnimation {
                            vocalsLevel = 0.0
                            drumsLevel = 1.0
                            bassLevel = 1.0
                            otherLevel = 1.0
                        }
                    }
                    StemPresetButton(name: "Vocals Only") {
                        withAnimation {
                            vocalsLevel = 1.0
                            drumsLevel = 0.0
                            bassLevel = 0.0
                            otherLevel = 0.0
                        }
                    }
                    StemPresetButton(name: "Bass Heavy") {
                        withAnimation {
                            vocalsLevel = 0.5
                            drumsLevel = 0.5
                            bassLevel = 1.5
                            otherLevel = 0.3
                        }
                    }
                    StemPresetButton(name: "Drums Only") {
                        withAnimation {
                            vocalsLevel = 0.0
                            drumsLevel = 1.0
                            bassLevel = 0.0
                            otherLevel = 0.0
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Play controls
            Button {
                isPlaying.toggle()
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
            .padding(.bottom, 30)
        }
        .padding(.top, 20)
    }
}

struct StemSlider: View {
    let name: String
    let icon: String
    @Binding var level: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(level > 0 ? 0.3 : 0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(level > 0 ? color : .gray)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(level * 100))%")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Slider(value: $level, in: 0...1.5)
                    .tint(color)
            }
            
            // Mute button
            Button {
                withAnimation {
                    level = level > 0 ? 0 : 1.0
                }
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: level > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 16))
                    .foregroundColor(level > 0 ? .white : .red)
            }
        }
    }
}

struct StemPresetButton: View {
    let name: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
            HapticManager.shared.impact(style: .light)
        }) {
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.white.opacity(0.15))
                )
        }
    }
}




