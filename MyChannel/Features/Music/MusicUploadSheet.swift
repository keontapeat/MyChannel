//
//  MusicUploadSheet.swift
//  MyChannel
//
//  Artist track upload flow — title, genre, artwork, audio file.
//  Saves metadata to Firestore `music_tracks` and audio to Firebase Storage.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct MusicUploadSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var trackTitle = ""
    @State private var artistName = ""
    @State private var albumName = ""
    @State private var selectedGenre = "Hip-Hop"
    @State private var isExplicit = false

    @State private var selectedArtworkItem: PhotosPickerItem?
    @State private var artworkImage: UIImage?
    @State private var showAudioPicker = false
    @State private var selectedAudioURL: URL?
    @State private var audioFileName = ""

    @State private var uploadState: UploadState = .idle
    @State private var uploadProgress: Double = 0
    @State private var errorMessage: String?
    @State private var showSuccess = false

    private let genres = [
        "Hip-Hop", "R&B", "Pop", "Rock", "Electronic", "Country",
        "Afrobeats", "Latin", "Jazz", "Indie", "Gospel", "Trap",
        "Soul", "Drill", "Alternative", "Lo-Fi", "Michigan Rap"
    ]

    enum UploadState {
        case idle, uploading, done, error
    }

    var body: some View {
        NavigationStack {
            Form {
                trackInfoSection
                artworkSection
                audioSection
                settingsSection

                if uploadState == .uploading {
                    Section {
                        VStack(spacing: 8) {
                            ProgressView(value: uploadProgress)
                                .tint(AppTheme.Colors.primary)
                            Text("\(Int(uploadProgress * 100))% uploaded")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .padding(.vertical, 8)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button {
                        Task { await uploadTrack() }
                    } label: {
                        HStack {
                            Spacer()
                            if uploadState == .uploading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Upload Track")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(canUpload ? AppTheme.Colors.primary : Color.gray)
                    )
                    .disabled(!canUpload || uploadState == .uploading)
                }
            }
            .navigationTitle("Upload Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.impact(style: .light)
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .alert("Track Uploaded!", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your track is live on MyChannel Music. Streams will start counting toward your earnings.")
            }
        }
        .onChange(of: selectedArtworkItem) { item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    artworkImage = img
                }
            }
        }
    }

    // MARK: - Form Sections

    private var trackInfoSection: some View {
        Section(header: Text("Track Info")) {
            TextField("Track Title *", text: $trackTitle)
            TextField("Artist Name *", text: $artistName)
            TextField("Album / Project (optional)", text: $albumName)
            Picker("Genre", selection: $selectedGenre) {
                ForEach(genres, id: \.self) { Text($0).tag($0) }
            }
        }
    }

    private var artworkSection: some View {
        Section(header: Text("Artwork")) {
            PhotosPicker(selection: $selectedArtworkItem, matching: .images) {
                HStack(spacing: 14) {
                    if let img = artworkImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.Colors.primary)
                            )
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(artworkImage == nil ? "Add Artwork" : "Change Artwork")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                        Text("Recommended: 3000×3000px")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var audioSection: some View {
        Section(header: Text("Audio File")) {
            Button {
                showAudioPicker = true
            } label: {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selectedAudioURL != nil ? AppTheme.Colors.primary.opacity(0.15) : AppTheme.Colors.surface)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: selectedAudioURL != nil ? "waveform" : "music.note.list")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.Colors.primary)
                        )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(audioFileName.isEmpty ? "Select Audio File *" : audioFileName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(audioFileName.isEmpty ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                        Text("MP3, M4A, AAC, WAV supported")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    Spacer()
                    if selectedAudioURL != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .fileImporter(
                isPresented: $showAudioPicker,
                allowedContentTypes: [.audio, UTType("public.mp3")!, UTType("com.apple.m4a-audio")!,
                                      UTType("com.apple.coreaudio-format")!, .wav],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectedAudioURL = url
                        audioFileName = url.lastPathComponent
                    }
                case .failure(let error):
                    errorMessage = "Could not load audio: \(error.localizedDescription)"
                }
            }
        }
    }

    private var settingsSection: some View {
        Section(header: Text("Settings")) {
            Toggle("Explicit Content", isOn: $isExplicit)
        }
    }

    // MARK: - Validation

    private var canUpload: Bool {
        !trackTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !artistName.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedAudioURL != nil
    }

    // MARK: - Upload

    private func uploadTrack() async {
        guard canUpload else { return }
        uploadState = .uploading
        uploadProgress = 0
        errorMessage = nil

        #if canImport(FirebaseAuth) && canImport(FirebaseStorage) && canImport(FirebaseFirestore)
        let artistId = Auth.auth().currentUser?.uid ?? UUID().uuidString
        let trackId = UUID().uuidString
        let storage = Storage.storage()
        let db = Firestore.firestore()

        do {
            var artworkURLString: String? = nil

            // 1. Upload artwork if selected
            if let artwork = artworkImage,
               let jpegData = artwork.jpegData(compressionQuality: 0.85) {
                let artRef = storage.reference().child("music/\(artistId)/artwork/\(trackId).jpg")
                uploadProgress = 0.1
                _ = try await artRef.putDataAsync(jpegData)
                artworkURLString = try await artRef.downloadURL().absoluteString
                uploadProgress = 0.4
            } else {
                uploadProgress = 0.2
            }

            // 2. Upload audio file
            guard let audioURL = selectedAudioURL else { return }
            let audioData = try Data(contentsOf: audioURL)
            let ext = audioURL.pathExtension.lowercased()
            let contentType = ext == "mp3" ? "audio/mpeg" : (ext == "wav" ? "audio/wav" : "audio/m4a")
            let audioRef = storage.reference().child("music/\(artistId)/tracks/\(trackId).\(ext)")
            let meta = StorageMetadata()
            meta.contentType = contentType

            uploadProgress = 0.45
            _ = try await audioRef.putDataAsync(audioData, metadata: meta)
            uploadProgress = 0.85
            let audioDownloadURL = try await audioRef.downloadURL().absoluteString
            uploadProgress = 0.9

            // 3. Save metadata to Firestore
            let trackData: [String: Any] = [
                "id": trackId,
                "title": trackTitle.trimmingCharacters(in: .whitespaces),
                "artistId": artistId,
                "artistName": artistName.trimmingCharacters(in: .whitespaces),
                "album": albumName.trimmingCharacters(in: .whitespaces),
                "genre": selectedGenre,
                "isExplicit": isExplicit,
                "artworkURL": artworkURLString as Any,
                "audioURL": audioDownloadURL,
                "streamCount": 0,
                "likeCount": 0,
                "uploadedAt": FieldValue.serverTimestamp(),
                "isPublished": true
            ]
            try await db.collection("music_tracks").document(trackId).setData(trackData)
            uploadProgress = 1.0
            uploadState = .done
            showSuccess = true

        } catch {
            uploadState = .error
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
        #else
        // Simulate upload in dev builds without Firebase
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            uploadProgress = Double(i) / 10.0
        }
        uploadState = .done
        showSuccess = true
        #endif
    }
}
