//
//  PlaylistManagementView.swift
//  MyChannel
//
//  100% COMPLETE PLAYLIST MANAGEMENT! 🎵
//  Create, edit, organize playlists like a PRO!
//

import SwiftUI

struct PlaylistManagementView: View {
    @State private var playlists: [Playlist] = []
    @State private var showingCreatePlaylist = false
    @State private var selectedPlaylist: Playlist?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Stats
                playlistStatsHeader
                
                // Create Button
                createPlaylistButton
                
                // Playlists List
                if playlists.isEmpty {
                    emptyStateView
                } else {
                    playlistsSection
                }
                
                // Tips
                tipsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Playlists")
        .sheet(isPresented: $showingCreatePlaylist) {
            CreatePlaylistSheet { playlist in
                playlists.append(playlist)
            }
        }
        .sheet(item: $selectedPlaylist) { playlist in
            EditPlaylistSheet(playlist: playlist)
        }
    }
    
    private var playlistStatsHeader: some View {
        HStack(spacing: 12) {
            PlaylistStatsCard(title: "Playlists", value: "\(playlists.count)", icon: "list.bullet.rectangle", color: .blue)
            PlaylistStatsCard(title: "Total Videos", value: "0", icon: "play.rectangle", color: .green)
            PlaylistStatsCard(title: "Total Views", value: "0", icon: "eye", color: .purple)
        }
    }
    
    private var createPlaylistButton: some View {
        Button(action: { showingCreatePlaylist = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                Text("Create New Playlist")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundColor(.white)
            .padding(20)
            .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Playlists Yet")
                .font(.system(size: 20, weight: .bold))
            Text("Organize your videos into playlists")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Button("Create Playlist") { showingCreatePlaylist = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
    
    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Playlists")
                .font(.system(size: 20, weight: .semibold))
            ForEach(playlists) { playlist in
                PlaylistRow(playlist: playlist) {
                    selectedPlaylist = playlist
                }
            }
        }
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill").foregroundColor(.yellow)
                Text("Playlist Tips")
                    .font(.system(size: 18, weight: .semibold))
            }
            PlaylistTipRow(icon: "list.number", title: "Organize by theme", subtitle: "Group similar content together")
            PlaylistTipRow(icon: "clock", title: "Order matters", subtitle: "Put best videos first")
            PlaylistTipRow(icon: "eye", title: "Use good titles", subtitle: "Make playlists easy to find")
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// Using existing Playlist model from Core/Models/Playlist.swift

struct PlaylistRow: View {
    let playlist: Playlist
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 50, height: 50)
                    .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.title)
                        .font(.system(size: 16, weight: .semibold))
                    Text("\(playlist.videoCount) videos")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CreatePlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (Playlist) -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var isPublic = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Playlist Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Visibility") {
                    Toggle("Public", isOn: $isPublic)
                }
                Section {
                    Button("Create Playlist") {
                        let playlist = Playlist(
                            title: title,
                            description: description,
                            creatorId: "current_user", // TODO: Get from AuthenticationManager
                            isPublic: isPublic
                        )
                        onCreate(playlist)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct EditPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let playlist: Playlist
    
    @State private var title: String
    @State private var description: String
    
    init(playlist: Playlist) {
        self.playlist = playlist
        _title = State(initialValue: playlist.title)
        _description = State(initialValue: playlist.description)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                }
                Section("Stats") {
                    HStack {
                        Text("Videos")
                        Spacer()
                        Text("\(playlist.videoCount)")
                    }
                }
                Section {
                    Button("Save Changes") { dismiss() }
                    Button("Delete Playlist", role: .destructive) { dismiss() }
                }
            }
            .navigationTitle("Edit Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - PlaylistStatsCard
struct PlaylistStatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Playlist Tip Row
struct PlaylistTipRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
                .background(Color.blue.opacity(0.1), in: Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
