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
    
    private var sampleMusic: [CreateStoryViewModel.MusicItem] {
        [
            CreateStoryViewModel.MusicItem(
                title: "Upbeat Vibes",
                artist: "Artist One",
                previewURL: "https://example.com/music1.mp3",
                artworkURL: "https://picsum.photos/200/200?random=1"
            ),
            CreateStoryViewModel.MusicItem(
                title: "Chill Beats",
                artist: "Artist Two",
                previewURL: "https://example.com/music2.mp3",
                artworkURL: "https://picsum.photos/200/200?random=2"
            ),
            CreateStoryViewModel.MusicItem(
                title: "Summer Anthem",
                artist: "Artist Three",
                previewURL: "https://example.com/music3.mp3",
                artworkURL: "https://picsum.photos/200/200?random=3"
            ),
            CreateStoryViewModel.MusicItem(
                title: "Electronic Flow",
                artist: "Artist Four",
                previewURL: "https://example.com/music4.mp3",
                artworkURL: "https://picsum.photos/200/200?random=4"
            ),
            CreateStoryViewModel.MusicItem(
                title: "Acoustic Dreams",
                artist: "Artist Five",
                previewURL: "https://example.com/music5.mp3",
                artworkURL: "https://picsum.photos/200/200?random=5"
            )
        ]
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
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
                
                // Category selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(MusicCategory.allCases, id: \.self) { category in
                            Button(action: { selectedCategory = category }) {
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
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                
                // Music list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sampleMusic, id: \.id) { music in
                            MusicRowView(
                                music: music,
                                isSelected: selectedMusic?.id == music.id,
                                isPlaying: currentlyPlaying == music.id,
                                onPlayPause: { 
                                    togglePlayback(for: music)
                                },
                                onSelect: {
                                    onMusicSelected(music)
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding()
                }
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
        }
    }
    
    private func togglePlayback(for music: CreateStoryViewModel.MusicItem) {
        if currentlyPlaying == music.id {
            currentlyPlaying = nil // Stop
        } else {
            currentlyPlaying = music.id // Play
        }
        HapticManager.shared.selection()
    }
}

// MARK: - Music Row View
struct MusicRowView: View {
    let music: CreateStoryViewModel.MusicItem
    let isSelected: Bool
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onSelect: () -> Void
    
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

#Preview {
    @State var selectedMusic: CreateStoryViewModel.MusicItem? = nil
    return MusicPickerSheet(selectedMusic: $selectedMusic) { music in
        print("Music selected: \(music.title)")
    }
}