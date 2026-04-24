//
//  MusicPickerSheet.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct MusicPickerSheet: View {
    @Binding var selectedMusic: CreateStoryViewModel.MusicItem?
    let onMusicSelected: (CreateStoryViewModel.MusicItem) -> Void
    
    @State private var searchText = ""
    @State private var selectedCategory: MusicCategory = .trending
    @State private var currentlyPlaying: String? = nil
    @State private var isSearching = false
    @State private var recentSearches: [String] = []
    @Environment(\.dismiss) private var dismiss
    
    enum MusicCategory: CaseIterable {
        case trending
        case pop
        case hiphop
        case rock
        case electronic
        case chill
        
        var title: String {
            switch self {
            case .trending: return "Trending"
            case .pop: return "Pop"
            case .hiphop: return "Hip Hop"
            case .rock: return "Rock"
            case .electronic: return "Electronic"
            case .chill: return "Chill"
            }
        }
    }
    
    @State private var results: [CatalogSong] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                recentSearchesSection
                categorySelector
                musicList
            }
            .navigationTitle("Add Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task { await loadInitial() }
            .onAppear { loadRecentSearches() }
            .onChange(of: searchText) { newValue in
                Task {
                    await searchCatalog(for: newValue)
                }
            }
        }
    }
    
    private func togglePlayback(for music: CreateStoryViewModel.MusicItem) {
        HapticManager.shared.selection()
        let trackId = music.id.uuidString
        if currentlyPlaying == trackId {
            AudioPreviewPlayer.shared.pause()
            currentlyPlaying = nil
            return
        }
        guard let url = URL(string: music.previewURL) else { return }
        AudioPreviewPlayer.shared.play(url: url, trackId: trackId)
        currentlyPlaying = trackId
    }
    
    // MARK: - View Components
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search music...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding()
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(MusicCategory.allCases, id: \.self) { category in
                    categoryButton(for: category)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
    }
    
    private func categoryButton(for category: MusicCategory) -> some View {
        Button(action: {
            selectedCategory = category
            Task { await loadCategory(category) }
        }) {
            Text(category.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(selectedCategory == category ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    selectedCategory == category ? AppTheme.Colors.primary : Color(.systemGray6)
                )
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var musicList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }

                if !isSearching && results.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "No songs found" : "No results for \"(searchText)\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }

                ForEach(results, id: \.id) { s in
                    let item = CreateStoryViewModel.MusicItem(
                        title: s.title,
                        artist: s.artist,
                        previewURL: s.previewUrl ?? "",
                        artworkURL: s.artworkUrl
                    )
                    MusicRowView(
                        music: item,
                        isSelected: selectedMusic?.id == item.id,
                        isPlaying: currentlyPlaying == item.id.uuidString,
                        onPlayPause: { togglePlayback(for: item) },
                        onSelect: {
                            onMusicSelected(item)
                            dismiss()
                        }
                    )
                }
            }
            .padding()
        }
    }

    private var recentSearchesSection: some View {
        Group {
            if !recentSearches.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recentSearches, id: \.self) { term in
                            Button {
                                searchText = term
                                Task {
                                    await searchCatalog(for: term)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.caption)
                                    Text(term)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Data loading
extension MusicPickerSheet {
    private func loadRecentSearches() {
        if let stored = UserDefaults.standard.array(forKey: "story_music_recent_searches") as? [String] {
            recentSearches = stored
        }
    }

    private func storeRecentSearch(_ term: String) {
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        recentSearches.insert(normalized, at: 0)
        if recentSearches.count > 12 {
            recentSearches = Array(recentSearches.prefix(12))
        }
        UserDefaults.standard.set(recentSearches, forKey: "story_music_recent_searches")
    }

    private func loadInitial() async {
        if results.isEmpty {
            let musicKit = MusicKitService.shared
            if musicKit.authorizationStatus != .authorized {
                _ = await musicKit.requestAuthorization()
            }

            if musicKit.authorizationStatus == .authorized,
               let chartTracks = try? await musicKit.getTopCharts(limit: 40),
               !chartTracks.isEmpty {
                results = chartTracks.map { track in
                    CatalogSong(
                        id: Int(track.id) ?? track.id.hashValue,
                        title: track.title,
                        artist: track.artistName,
                        artworkUrl: track.artworkURL?.absoluteString,
                        previewUrl: track.previewURL?.absoluteString,
                        trackViewUrl: nil,
                        collectionName: track.albumTitle,
                        primaryGenreName: track.genres.first,
                        releaseDate: nil,
                        artistId: nil
                    )
                }
            } else if let items = try? await MusicCatalogService.shared.topSongs(limit: 40) {
                results = items
            }
        }
    }
    
    private func loadCategory(_ category: MusicCategory) async {
        let term: String
        switch category {
        case .trending: term = "top songs"
        case .pop: term = "pop"
        case .hiphop: term = "hip hop"
        case .rock: term = "rock"
        case .electronic: term = "electronic"
        case .chill: term = "chill"
        }
        if let items = try? await MusicCatalogService.shared.genreSongs(term, limit: 40) {
            results = items
        }
    }

    private func searchCatalog(for term: String) async {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isSearching = false
            await loadCategory(selectedCategory)
            return
        }

        isSearching = true
        defer { isSearching = false }
        storeRecentSearch(trimmed)

        let musicKit = MusicKitService.shared
        if musicKit.authorizationStatus == .authorized,
           let musicKitItems = try? await musicKit.search(term: trimmed, limit: 50),
           !musicKitItems.isEmpty {
            results = musicKitItems.map { track in
                CatalogSong(
                    id: Int(track.id) ?? track.id.hashValue,
                    title: track.title,
                    artist: track.artistName,
                    artworkUrl: track.artworkURL?.absoluteString,
                    previewUrl: track.previewURL?.absoluteString,
                    trackViewUrl: nil,
                    collectionName: track.albumTitle,
                    primaryGenreName: track.genres.first,
                    releaseDate: nil,
                    artistId: nil
                )
            }
        } else if let items = try? await MusicCatalogService.shared.searchSongs(term: trimmed, limit: 50) {
            results = items
        } else {
            results = []
        }
    }
}

// MARK: - Music Row View
struct MusicRowView: View {
    let music: CreateStoryViewModel.MusicItem
    let isSelected: Bool
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onSelect: () -> Void
    @ObservedObject private var preview = AudioPreviewPlayer.shared
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Album artwork
                AsyncImage(url: URL(string: music.artworkURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
                
                // Music info
                VStack(alignment: .leading, spacing: 4) {
                    Text(music.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(music.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if isPlaying {
                            // Waveform visualization
                            HStack(spacing: 2) {
                                ForEach(0..<8, id: \.self) { _ in
                                    WaveformBar()
                                }
                            }
                        } else {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(Int(music.duration))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Play button
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.primary)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.Colors.primary.opacity(0.1))
                        .cornerRadius(16)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Select indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AppTheme.Colors.primary : .gray)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            // Progress bar below
            if isPlaying {
                ProgressView(value: preview.progress)
                    .progressViewStyle(.linear)
                    .tint(AppTheme.Colors.primary)
                    .padding(.horizontal)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Waveform Bar
struct WaveformBar: View {
    @State private var height: CGFloat = 2
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(AppTheme.Colors.primary)
            .frame(width: 2, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    height = CGFloat.random(in: 2...12)
                }
            }
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @State var selectedMusic: CreateStoryViewModel.MusicItem? = nil
    MusicPickerSheet(selectedMusic: $selectedMusic) { music in
        print("Music selected: \(music.title)")
    }
}