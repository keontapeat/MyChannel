//
//  FlicksContentSheets.swift
//  MyChannel
//
//  Extracted sound / playlist / report sheets from FlicksView for faster parallel compiles.
//

import SwiftUI

struct FlicksSoundPageSheet: View {
    let sound: FlickMusicTrack
    let relatedFlicks: [NuclearFlick]
    let onDismiss: () -> Void
    var onCreatorTap: ((User) -> Void)? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        HapticManager.shared.impact(style: .light)
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel("Close")

                    Spacer()

                    Text("Sound")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    Button {
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel("Share sound")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()
                    .background(Color.gray.opacity(0.3))

                VStack(spacing: 16) {
                    AppAsyncImage(
                        url: URL(string: sound.albumArt),
                        content: { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        },
                        placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                    )
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .accessibilityLabel("Album art for \(sound.title)")

                    VStack(spacing: 8) {
                        Text(sound.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text(sound.artist)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        if let creatorFlick = relatedFlicks.first {
                            Button {
                                HapticManager.shared.impact(style: .light)
                                let user = User(
                                    id: creatorFlick.creator.id,
                                    username: creatorFlick.creator.username,
                                    displayName: creatorFlick.creator.displayName,
                                    email: "",
                                    profileImageURL: creatorFlick.creator.profileImageURL,
                                    isVerified: creatorFlick.creator.isVerified
                                )
                                onCreatorTap?(user)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.crop.circle")
                                    Text("View @\(creatorFlick.creator.username)")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.blue)
                            }
                            .accessibilityLabel("View sound creator profile")
                        }
                    }
                }
                .padding(.vertical, 32)

                Divider()
                    .background(Color.gray.opacity(0.3))

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(relatedFlicks) { flick in
                            HStack(spacing: 12) {
                                AppAsyncImage(
                                    url: URL(string: flick.thumbnailURL),
                                    content: { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    },
                                    placeholder: {
                                        Rectangle().fill(Color.gray.opacity(0.3))
                                    }
                                )
                                .frame(width: 80, height: 142)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(flick.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(2)

                                    Text("@\(flick.creator.username)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(flick.title) by @\(flick.creator.username)")
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct FlicksPlaylistPickerSheet: View {
    @Binding var newPlaylistName: String
    let playlists: [Playlist]
    let isLoading: Bool
    let onDismiss: () -> Void
    let onSelectPlaylist: (Playlist) -> Void
    let onCreateAndAdd: () -> Void
    let onLoad: () async -> Void

    private var isCreateDisabled: Bool {
        newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        HapticManager.shared.impact(style: .light)
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel("Close")

                    Spacer()

                    Text("Save to Playlist")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    Color.clear.frame(width: 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()
                    .background(Color.gray.opacity(0.3))

                if isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                        .accessibilityLabel("Loading playlists")
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            if playlists.isEmpty {
                                Text("No playlists yet. Create one below.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.vertical, 24)
                            }
                            ForEach(playlists) { playlist in
                                Button {
                                    HapticManager.shared.impact(style: .medium)
                                    onSelectPlaylist(playlist)
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white.opacity(0.8))
                                            .frame(width: 40)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(playlist.title)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white)
                                            Text("\(playlist.videoCount) videos")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.5))
                                        }

                                        Spacer()

                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(AppTheme.Colors.primary)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Add to \(playlist.title), \(playlist.videoCount) videos")

                                Divider()
                                    .background(Color.gray.opacity(0.2))
                            }
                        }
                    }
                }

                VStack(spacing: 12) {
                    TextField("New playlist name", text: $newPlaylistName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 20)
                        .accessibilityLabel("New playlist name")

                    Button("Create & Add") {
                        HapticManager.shared.impact(style: .medium)
                        onCreateAndAdd()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isCreateDisabled ? Color.gray : AppTheme.Colors.primary)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .disabled(isCreateDisabled)
                    .accessibilityLabel("Create playlist and add video")
                }
                .padding(.vertical, 20)
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await onLoad()
        }
    }
}

struct FlicksReportSheet: View {
    let onDismiss: () -> Void
    let onSelectReason: (FlicksFeedbackService.ReportReason) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Report")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button {
                        HapticManager.shared.impact(style: .light)
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Text("Why are you reporting this?")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                Divider().background(Color.gray.opacity(0.3))

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(FlicksFeedbackService.ReportReason.allCases) { reason in
                            Button {
                                HapticManager.shared.impact(style: .medium)
                                onSelectReason(reason)
                            } label: {
                                HStack {
                                    Text(reason.rawValue)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(reason.rawValue)

                            Divider().background(Color.gray.opacity(0.2))
                        }
                    }
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview("Sound Page") {
    FlicksSoundPageSheet(
        sound: FlickMusicTrack(
            title: "Preview Track",
            artist: "Preview Artist",
            albumArt: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
        ),
        relatedFlicks: [],
        onDismiss: {}
    )
}

#Preview("Playlist Picker") {
    FlicksPlaylistPickerSheet(
        newPlaylistName: .constant(""),
        playlists: [],
        isLoading: false,
        onDismiss: {},
        onSelectPlaylist: { _ in },
        onCreateAndAdd: {},
        onLoad: {}
    )
}

#Preview("Report") {
    FlicksReportSheet(
        onDismiss: {},
        onSelectReason: { _ in }
    )
}
