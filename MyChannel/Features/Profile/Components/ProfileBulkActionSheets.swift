//
//  ProfileBulkActionSheets.swift
//  MyChannel
//
//  Extracted from ProfileView.swift for better maintainability
//

import SwiftUI

// MARK: - Bulk Visibility Sheet

struct ProfileBulkVisibilitySheet: View {
    @Environment(\.dismiss) private var dismiss
    let selectedVideoIds: [String]
    let onApply: (Video.VisibilityStatus) -> Void
    
    @State private var selectedVisibility: Video.VisibilityStatus = .public
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(selectedVideoIds.count) video\(selectedVideoIds.count == 1 ? "" : "s") selected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Section("Visibility") {
                    ForEach(Video.VisibilityStatus.allCases, id: \.self) { visibility in
                        Button {
                            selectedVisibility = visibility
                        } label: {
                            HStack {
                                Image(systemName: visibility.iconName)
                                Text(visibility.displayName)
                                Spacer()
                                if selectedVisibility == visibility {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button("Apply") {
                        onApply(selectedVisibility)
                        dismiss()
                    }
                    .disabled(selectedVideoIds.isEmpty)
                }
            }
            .navigationTitle("Change Visibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Bulk Playlist Sheet

struct ProfileBulkPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let playlists: [Playlist]
    let isLoading: Bool
    let selectedVideoIds: [String]
    let onApply: (Set<String>) -> Void
    
    @State private var selectedPlaylists: Set<String> = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(selectedVideoIds.count) video\(selectedVideoIds.count == 1 ? "" : "s") selected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                if isLoading {
                    Section {
                        ProgressView("Loading playlists…")
                    }
                } else if playlists.isEmpty {
                    Section {
                        Text("You haven't created any playlists yet.")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                } else {
                    Section("Add to Playlists") {
                        ForEach(playlists, id: \.id) { playlist in
                            Button {
                                toggleSelection(for: playlist.id)
                            } label: {
                                HStack {
                                    Image(systemName: selectedPlaylists.contains(playlist.id) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(selectedPlaylists.contains(playlist.id) ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                                    Text(playlist.title)
                                    Spacer()
                                    Text("\(playlist.videoCount) videos")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button("Add to Selected Playlists") {
                        onApply(selectedPlaylists)
                        dismiss()
                    }
                    .disabled(selectedPlaylists.isEmpty || selectedVideoIds.isEmpty)
                }
            }
            .navigationTitle("Add to Playlists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func toggleSelection(for playlistId: String) {
        if selectedPlaylists.contains(playlistId) {
            selectedPlaylists.remove(playlistId)
        } else {
            selectedPlaylists.insert(playlistId)
        }
    }
}

// MARK: - Bulk Undo Payload

struct BulkUndoPayload: Identifiable, Equatable {
    enum Action: Equatable {
        case delete(videos: [Video])
    }
    
    let id = UUID()
    let action: Action
    
    var message: String {
        switch action {
        case .delete(let videos):
            return "Deleted \(videos.count) video\(videos.count == 1 ? "" : "s")"
        }
    }
}

// MARK: - Previews

#Preview("Bulk Visibility Sheet") {
    ProfileBulkVisibilitySheet(
        selectedVideoIds: ["1", "2", "3"]
    ) { visibility in
        print("Selected: \(visibility)")
    }
}

#Preview("Bulk Playlist Sheet") {
    ProfileBulkPlaylistSheet(
        playlists: [],
        isLoading: false,
        selectedVideoIds: ["1", "2"]
    ) { playlists in
        print("Selected playlists: \(playlists)")
    }
}

#Preview("Bulk Playlist Sheet - Loading") {
    ProfileBulkPlaylistSheet(
        playlists: [],
        isLoading: true,
        selectedVideoIds: ["1", "2"]
    ) { _ in }
}







