import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct OwnerFeaturedManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = FeaturedStore.shared
    @State private var showingAddSheet = false
    @State private var showingPicker = false
    @State private var pickedItemURL: URL?
    @State private var showingAdminView = false
    @StateObject private var cameraRollUploader = CameraRollFeaturedUploader()

    var body: some View {
        List {
            if store.featured.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle")
                            .font(.system(size: 42))
                            .foregroundColor(.yellow)
                        Text("No Featured videos yet")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Tap Add to pick videos to feature on Home.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }

            Section("Featured Today (Drag to reorder)") {
                ForEach(store.featured) { item in
                    HStack(spacing: 12) {
                        AppAsyncImage(url: URL(string: item.thumb)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: { Color(.systemGray6) }
                        .frame(width: 80, height: 45)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(2)
                            Text(item.creatorName)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            store.remove(item.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onMove { indices, newOffset in
                    store.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Manage Featured")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingAdminView = true
                    } label: {
                        Label("Manage Paid Features", systemImage: "star.circle.fill")
                    }
                    
                    Divider()
                    
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add from library", systemImage: "plus")
                    }
                    Button {
                        showingPicker = true
                    } label: {
                        Label("Add from camera roll", systemImage: "photo.on.rectangle")
                    }
                } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            OwnerFeaturedPickerView { video in
                FeaturedStore.shared.add(video)
            }
        }
        .sheet(isPresented: $showingPicker) {
            DocumentPicker(types: ["public.movie"]) { url in
                guard let url else { return }
                Task {
                    if let video = await cameraRollUploader.upload(
                        videoURL: url,
                        title: "Owner Upload",
                        description: "Added from camera roll",
                        thumbnail: nil
                    ) {
                        store.add(video)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingAdminView) {
            FeaturedVideoAdminView()
        }
    }
}

private struct OwnerFeaturedPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (Video) -> Void

    @State private var firestoreVideos: [Video] = []

    private var candidates: [Video] {
        var vids: [Video] = []
        if let intro = ownerIntroVideo() { vids.append(intro) }
        vids.append(contentsOf: SeedCatalogService.shared.seedVideos)
        vids.append(contentsOf: firestoreVideos)
        return Array(Set(vids)).prefix(50).map { $0 }
    }

    private func ownerIntroVideo() -> Video? {
        let currentUser = AppState.shared.currentUser ?? AuthenticationManager.shared.currentUser
        let me = currentUser ?? User(
            id: "sbkeonta_owner",
            username: "sbkeonta_",
            displayName: "Shot By Keonta",
            email: "keontapeat@mychannel.live",
            profileImageURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop",
            isVerified: true,
            isCreator: true
        )
        return Video(
            id: "owner_intro_video",
            title: "Shot By Keonta Intro",
            description: "Welcome to MyChannel - Shot By Keonta 🎬🔥",
            thumbnailURL: "asset://ShotByKeontaThumbnail",
            videoURL: "https://firebasestorage.googleapis.com/v0/b/mychannel-ca26d.firebasestorage.app/o/Shot%20By%20Keonta%20Intro%204k.MP4?alt=media&token=88e366e2-efde-4631-9707-d7e9fadc9568",
            duration: 35,
            viewCount: 0,
            likeCount: 0,
            creator: me,
            category: .entertainment,
            tags: ["intro", "keonta", "mychannel"],
            isPublic: true
        )
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(candidates) { video in
                    Button {
                        onPick(video)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            AppAsyncImage(url: URL(string: video.thumbnailURL)) { img in
                                img.resizable().scaledToFill()
                            } placeholder: { Color(.systemGray6) }
                            .frame(width: 100, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(video.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(2)
                                Text(video.creator.displayName)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Add Featured")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                firestoreVideos = await VideoFirestoreService.shared.fetchAllPublicVideos(limit: 50)
            }
        }
    }
}

// MARK: - Bulk Add Friends
struct OwnerBulkFriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var input: String = ""
    @StateObject private var store = OwnerFriendsStore.shared

    var body: some View {
        Form {
            Section("Paste handles / names") {
                TextEditor(text: $input)
                    .frame(minHeight: 160)
                    .font(.system(.body, design: .monospaced))
            }
            Section("How it works") {
                Text("One per line. Formats supported:")
                Text("@handle")
                Text("Display Name,@handle")
                Text("Display Name|@handle|https://avatar.jpg")
            }
        }
        .navigationTitle("Bulk Add Friends")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Import") {
                    OwnerFriendsStore.shared.importFromString(input)
                    dismiss()
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

// Simple UIDocumentPicker wrapper to import videos from Files/Photos
private struct DocumentPicker: UIViewControllerRepresentable {
    var types: [String]
    var onPick: (URL?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types.compactMap { UTType($0) })
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL?) -> Void
        init(onPick: @escaping (URL?) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onPick(nil) }
    }
}
