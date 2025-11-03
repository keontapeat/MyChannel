//
//  SmartPlaylistsView.swift
//  MyChannel
//
//  AI-CURATED SMART PLAYLISTS - Auto-generated playlists based on AI analysis
//  Better than Spotify's algorithm!
//  Created for MyChannel by AI Assistant
//

import SwiftUI

struct SmartPlaylistsView: View {
    @StateObject private var viewModel = SmartPlaylistsViewModel()
    @State private var selectedPlaylist: SmartPlaylist?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Hero Section
                        playlistsHero
                        
                        // AI Recommendations
                        aiRecommendationsSection
                        
                        // Your Smart Playlists
                        yourPlaylistsSection
                        
                        // Trending Playlists
                        trendingPlaylistsSection
                        
                        // Mood-Based Playlists
                        moodPlaylistsSection
                        
                        // Activity-Based Playlists
                        activityPlaylistsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Smart Playlists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Create custom playlist
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
        }
        .sheet(item: $selectedPlaylist) { playlist in
            PlaylistDetailSheet(playlist: playlist)
        }
        .onAppear {
            Task {
                await viewModel.loadPlaylists()
            }
        }
    }
    
    // MARK: - Hero Section
    private var playlistsHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.2, blue: 0.9),
                            Color(red: 0.6, green: 0.3, blue: 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
            
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 30, weight: .bold))
                    Text("Smart Playlists")
                        .font(.system(size: 26, weight: .bold))
                }
                .foregroundColor(.white)
                
                Text("AI-curated playlists that know what you want")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 14) {
                    featureBadge(icon: "brain.head.profile", text: "AI Powered")
                    featureBadge(icon: "sparkles", text: "Auto-Updated")
                    featureBadge(icon: "infinity", text: "Endless")
                }
            }
            .padding(24)
        }
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private func featureBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
    }
    
    // MARK: - AI Recommendations
    private var aiRecommendationsSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.purple)
                    
                    Text("Made For You")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.aiRecommendedPlaylists) { playlist in
                        AIPlaylistCard(playlist: playlist) {
                            selectedPlaylist = playlist
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Your Playlists
    private var yourPlaylistsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Playlists")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(viewModel.yourPlaylists.count)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(viewModel.yourPlaylists) { playlist in
                    PlaylistCard(playlist: playlist) {
                        selectedPlaylist = playlist
                    }
                }
            }
        }
    }
    
    // MARK: - Trending Playlists
    private var trendingPlaylistsSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                    
                    Text("Trending Now")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.trendingPlaylists) { playlist in
                        TrendingPlaylistCard(playlist: playlist) {
                            selectedPlaylist = playlist
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Mood Playlists
    private var moodPlaylistsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("By Mood")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(MoodType.allMoods) { mood in
                    MoodButton(mood: mood) {
                        // Filter by mood
                    }
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Activity Playlists
    private var activityPlaylistsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("By Activity")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            ForEach(viewModel.activityPlaylists) { playlist in
                ActivityPlaylistRow(playlist: playlist) {
                    selectedPlaylist = playlist
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Supporting Views

struct AIPlaylistCard: View {
    let playlist: SmartPlaylist
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Cover Art
                ZStack(alignment: .topTrailing) {
                    if !playlist.coverImages.isEmpty {
                        // Grid of thumbnails
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                            ForEach(playlist.coverImages.prefix(4), id: \.self) { imageURL in
                                AsyncImage(url: URL(string: imageURL)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(AppTheme.Colors.cardBackground)
                                }
                                .frame(width: 95, height: 95)
                                .clipShape(Rectangle())
                            }
                        }
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(playlist.color.opacity(0.3))
                            .frame(width: 200, height: 200)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 64))
                                    .foregroundColor(playlist.color)
                            )
                    }
                    
                    // AI Badge
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                        Text("AI")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.purple)
                    .clipShape(Capsule())
                    .padding(8)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(playlist.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Text(playlist.description)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 12))
                        Text("\(playlist.videoCount) videos")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            .frame(width: 200)
        }
    }
}

struct PlaylistCard: View {
    let playlist: SmartPlaylist
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                // Cover
                ZStack(alignment: .bottomTrailing) {
                    if !playlist.coverImages.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 1) {
                            ForEach(playlist.coverImages.prefix(4), id: \.self) { imageURL in
                                AsyncImage(url: URL(string: imageURL)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(AppTheme.Colors.cardBackground)
                                }
                                .frame(height: 80)
                                .clipShape(Rectangle())
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(playlist.color.opacity(0.2))
                            .frame(height: 160)
                            .overlay(
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 48))
                                    .foregroundColor(playlist.color)
                            )
                    }
                    
                    // Video count badge
                    Text("\(playlist.videoCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.7))
                        .clipShape(Capsule())
                        .padding(8)
                }
                .frame(height: 160)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    if playlist.isAutoUpdating {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                            Text("Auto-updating")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.green)
                    }
                }
            }
            .padding(10)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct TrendingPlaylistCard: View {
    let playlist: SmartPlaylist
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    if let firstImage = playlist.coverImages.first {
                        AsyncImage(url: URL(string: firstImage)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(AppTheme.Colors.cardBackground)
                        }
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("HOT")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange)
                    .clipShape(Capsule())
                    .padding(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Text("\(playlist.totalViews.abbreviated) views")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .frame(width: 160)
        }
    }
}

struct MoodButton: View {
    let mood: MoodType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(mood.emoji)
                    .font(.system(size: 32))
                
                Text(mood.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(mood.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(mood.color.opacity(0.3), lineWidth: 2)
            )
        }
    }
}

struct ActivityPlaylistRow: View {
    let playlist: SmartPlaylist
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(playlist.color.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: playlist.icon)
                        .font(.system(size: 28))
                        .foregroundColor(playlist.color)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(playlist.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("\(playlist.videoCount) videos • \(playlist.totalDuration)")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(12)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Playlist Detail Sheet
struct PlaylistDetailSheet: View {
    let playlist: SmartPlaylist
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Playlist Header
                    VStack(spacing: 16) {
                        if !playlist.coverImages.isEmpty {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                                ForEach(playlist.coverImages.prefix(4), id: \.self) { imageURL in
                                    AsyncImage(url: URL(string: imageURL)) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle().fill(AppTheme.Colors.cardBackground)
                                    }
                                    .frame(height: 120)
                                    .clipShape(Rectangle())
                                }
                            }
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        
                        Text(playlist.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text(playlist.description)
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 20) {
                            VStack(spacing: 4) {
                                Text("\(playlist.videoCount)")
                                    .font(.system(size: 20, weight: .bold))
                                Text("Videos")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            VStack(spacing: 4) {
                                Text(playlist.totalDuration)
                                    .font(.system(size: 20, weight: .bold))
                                Text("Duration")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            VStack(spacing: 4) {
                                Text(playlist.totalViews.abbreviated)
                                    .font(.system(size: 20, weight: .bold))
                                Text("Views")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                        
                        Button {
                            // Play all
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Play All")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.Colors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 4)
                        }
                    }
                    
                    // Video list would go here
                    Text("Video list coming soon")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(24)
            }
            .background(AppTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SmartPlaylistsView()
}

