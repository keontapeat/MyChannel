//
//  MusicPickerSheet.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct MusicPickerSheet: View {
    let onMusicSelected: (CreateStoryViewModel.MusicItem) -> Void
    
    @State private var searchText = ""
    @State private var selectedCategory: MusicCategory = .trending
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
                            MusicRowView(music: music) {
                                onMusicSelected(music)
                                dismiss()
                            }
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
}

// MARK: - Music Row View
struct MusicRowView: View {
    let music: CreateStoryViewModel.MusicItem
    let onSelect: () -> Void
    
    @State private var isPlaying = false
    
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
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(music.duration))s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Play button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPlaying.toggle()
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.primary)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.Colors.primary.opacity(0.1))
                        .cornerRadius(16)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Select indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MusicPickerSheet { music in
        print("Music selected: \(music.title)")
    }
}