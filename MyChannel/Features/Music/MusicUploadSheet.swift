//
//  MusicUploadSheet.swift
//  MyChannel
//
//  Artist track upload flow — title, genre, artwork, audio file.
//  Saves metadata to Firestore `music_tracks` and audio to Firebase Storage.
//

import SwiftUI
import PhotosUI
import AVFoundation
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
    @State private var featuredArtists = ""
    @State private var albumName = ""
    @State private var selectedGenre = "Hip-Hop"
    @State private var releaseType = "Single"
    @State private var trackLanguage = "en"
    @State private var isExplicit = false
    @State private var protectWithContentID = true
    @State private var selectedContentPolicy: ContentMatch.MatchPolicy = .track
    // Credits
    @State private var songwriter = ""
    @State private var producer = ""
    @State private var recordLabel = ""
    @State private var copyrightOwner = ""
    @State private var copyrightYear = String(Calendar.current.component(.year, from: Date()))
    // Lyrics
    @State private var lyrics = ""
    @State private var showLyricsEditor = false
    // Captured duration
    @State private var capturedDuration: Double = 0
    // Scheduling
    @State private var scheduleRelease = false
    @State private var releaseDate = Date()

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
    private let releaseTypes = ["Single", "EP", "Album"]
    private let languages = [
        ("en", "English"), ("es", "Spanish"), ("fr", "French"),
        ("de", "German"), ("pt", "Portuguese"), ("hi", "Hindi"),
        ("ja", "Japanese"), ("zh", "Chinese"), ("ar", "Arabic"),
        ("ru", "Russian"), ("ko", "Korean"), ("it", "Italian")
    ]

    enum UploadState {
        case idle, uploading, done, error
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero artwork picker
                    artworkHero
                    
                    // Track info card
                    uploadCard {
                        uploadSectionLabel("TRACK INFO")
                        uploadField("Song Title", text: $trackTitle, required: true)
                        Divider().padding(.leading, 16)
                        uploadField("Artist Name", text: $artistName, required: true)
                        Divider().padding(.leading, 16)
                        uploadField("Featured Artists", text: $featuredArtists, required: false)
                        Divider().padding(.leading, 16)
                        uploadField("Album / Project", text: $albumName, required: false)
                        Divider().padding(.leading, 16)
                        pickerRow("Genre", selection: $selectedGenre, options: genres)
                        Divider().padding(.leading, 16)
                        pickerRow("Release Type", selection: $releaseType, options: releaseTypes)
                        Divider().padding(.leading, 16)
                        HStack {
                            Text("Language")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Picker("", selection: $trackLanguage) {
                                ForEach(languages, id: \.0) { code, name in
                                    Text(name).tag(code)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(Color(red: 0.88, green: 0.15, blue: 0.25))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        Divider().padding(.leading, 16)
                        Toggle(isOn: $isExplicit) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14))
                                Text("Explicit Content")
                                    .font(.system(size: 15))
                            }
                        }
                        .tint(Color(red: 0.88, green: 0.15, blue: 0.25))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        Divider().padding(.leading, 16)
                        Toggle(isOn: $protectWithContentID) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Protect with Content ID")
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                Text("Register this track for automated copyright matching")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(Color(red: 0.88, green: 0.15, blue: 0.25))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        if protectWithContentID {
                            Divider().padding(.leading, 16)
                            HStack {
                                Text("Copyright Policy")
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                Spacer()
                                Picker("", selection: $selectedContentPolicy) {
                                    Text("Track").tag(ContentMatch.MatchPolicy.track)
                                    Text("Monetize").tag(ContentMatch.MatchPolicy.monetize)
                                    Text("Block").tag(ContentMatch.MatchPolicy.block)
                                    Text("Mute").tag(ContentMatch.MatchPolicy.mute)
                                }
                                .pickerStyle(.menu)
                                .accentColor(Color(red: 0.88, green: 0.15, blue: 0.25))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }

                    // Credits card
                    uploadCard {
                        uploadSectionLabel("CREDITS & RIGHTS")
                        uploadField("Songwriter", text: $songwriter, required: false)
                        Divider().padding(.leading, 16)
                        uploadField("Producer", text: $producer, required: false)
                        Divider().padding(.leading, 16)
                        uploadField("Record Label", text: $recordLabel, required: false)
                        Divider().padding(.leading, 16)
                        uploadField("© Copyright Owner", text: $copyrightOwner, required: false)
                        Divider().padding(.leading, 16)
                        HStack {
                            Text("℗ Year")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Picker("", selection: $copyrightYear) {
                                ForEach((2000...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                                    Text(String(year)).tag(String(year))
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(Color(red: 0.88, green: 0.15, blue: 0.25))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    // Lyrics card
                    uploadCard {
                        uploadSectionLabel("LYRICS (OPTIONAL)")
                        Button {
                            showLyricsEditor.toggle()
                        } label: {
                            HStack {
                                Image(systemName: lyrics.isEmpty ? "text.quote" : "checkmark.circle.fill")
                                    .foregroundColor(lyrics.isEmpty ? Color(red: 0.88, green: 0.15, blue: 0.25) : .green)
                                Text(lyrics.isEmpty ? "Add Lyrics" : "Lyrics added (\(lyrics.split(separator: "\n").count) lines)")
                                    .font(.system(size: 15))
                                    .foregroundColor(lyrics.isEmpty ? Color(red: 0.88, green: 0.15, blue: 0.25) : .primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 13))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }

                    // Scheduling card
                    uploadCard {
                        uploadSectionLabel("RELEASE SCHEDULE")
                        Toggle(isOn: $scheduleRelease) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Schedule release")
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                Text("Set a future release date for this track")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(Color(red: 0.88, green: 0.15, blue: 0.25))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        if scheduleRelease {
                            Divider().padding(.leading, 16)
                            DatePicker("Release date", selection: $releaseDate, in: Date()..., displayedComponents: [.date])
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                    }

                    // Audio file card
                    uploadCard {
                        uploadSectionLabel("AUDIO FILE")
                        Button { showAudioPicker = true } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selectedAudioURL != nil
                                              ? Color(red: 0.88, green: 0.15, blue: 0.25).opacity(0.12)
                                              : Color(.systemGray5))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: selectedAudioURL != nil ? "waveform" : "music.note.list")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Color(red: 0.88, green: 0.15, blue: 0.25))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(audioFileName.isEmpty ? "Choose Audio File" : audioFileName)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(audioFileName.isEmpty ? Color(red: 0.88, green: 0.15, blue: 0.25) : .primary)
                                        .lineLimit(1)
                                    Text("MP3 · WAV · M4A · AAC")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedAudioURL != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 20))
                                }
                            }
                            .padding(16)
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
                            case .failure(let err):
                                errorMessage = "Could not load audio: \(err.localizedDescription)"
                            }
                        }
                    }


                    // Upload progress
                    if uploadState == .uploading {
                        VStack(spacing: 8) {
                            ProgressView(value: uploadProgress)
                                .tint(Color(red: 0.88, green: 0.15, blue: 0.25))
                                .scaleEffect(x: 1, y: 1.5)
                            Text("Uploading… \(Int(uploadProgress * 100))%")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }

                    // Error message
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 20)
                    }

                    // Upload button
                    Button {
                        Task { await uploadTrack() }
                    } label: {
                        HStack(spacing: 10) {
                            if uploadState == .uploading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Upload Track")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Group {
                                if canUpload {
                                    LinearGradient(
                                        colors: [Color(red: 0.88, green: 0.15, blue: 0.25), Color(red: 0.58, green: 0.08, blue: 0.38)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                } else {
                                    LinearGradient(colors: [Color.gray, Color.gray], startPoint: .leading, endPoint: .trailing)
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: canUpload ? Color(red: 0.88, green: 0.15, blue: 0.25).opacity(0.35) : .clear,
                                radius: 10, x: 0, y: 4)
                    }
                    .disabled(!canUpload || uploadState == .uploading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Upload Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.impact(style: .light)
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.88, green: 0.15, blue: 0.25))
                }
            }
            .alert("Track Uploaded! 🎵", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your track is live on MyChannel Music. Streams will start counting toward your earnings.")
            }
        }
        .sheet(isPresented: $showLyricsEditor) {
            NavigationStack {
                TextEditor(text: $lyrics)
                    .padding(12)
                    .navigationTitle("Lyrics")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showLyricsEditor = false }
                                .foregroundColor(Color(red: 0.88, green: 0.15, blue: 0.25))
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Clear") { lyrics = "" }
                                .foregroundColor(.secondary)
                        }
                    }
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
        .onChange(of: selectedAudioURL) { url in
            guard let url else { return }
            Task {
                let asset = AVURLAsset(url: url)
                if let duration = try? await asset.load(.duration) {
                    capturedDuration = CMTimeGetSeconds(duration)
                }
            }
        }
    }

    // MARK: - Artwork Hero

    private var artworkHero: some View {
        PhotosPicker(selection: $selectedArtworkItem, matching: .images) {
            ZStack {
                if let img = artworkImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.88, green: 0.15, blue: 0.25).opacity(0.15),
                                         Color(red: 0.58, green: 0.08, blue: 0.38).opacity(0.1)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 180, height: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color(red: 0.88, green: 0.15, blue: 0.25).opacity(0.4),
                                                 Color(red: 0.58, green: 0.08, blue: 0.38).opacity(0.4)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 3])
                                )
                        )
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(Color(red: 0.88, green: 0.15, blue: 0.25))
                                Text("Add Cover Art")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(red: 0.88, green: 0.15, blue: 0.25))
                            }
                        )
                }

                // Edit badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.88, green: 0.15, blue: 0.25))
                                .frame(width: 32, height: 32)
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 6, y: 6)
                    }
                }
                .frame(width: 180, height: 180)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Reusable Card Components

    private func pickerRow(_ label: String, selection: Binding<String>, options: [String]) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .accentColor(Color(red: 0.88, green: 0.15, blue: 0.25))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func uploadCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 20)
    }

    private func uploadSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }

    private func uploadField(_ placeholder: String, text: Binding<String>, required: Bool) -> some View {
        HStack {
            TextField(required ? "\(placeholder) *" : placeholder, text: text)
                .font(.system(size: 15))
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            if required && !text.wrappedValue.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
                    .padding(.trailing, 16)
            }
        }
    }

    // MARK: - Validation

    private var canUpload: Bool {
        !trackTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !artistName.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedAudioURL != nil
    }

    private func generateISRC() -> String {
        let year = Calendar.current.component(.year, from: Date()) % 100
        let designation = Int.random(in: 10000...99999)
        return "US-MCH-\(String(format: "%02d", year))-\(designation)"
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

            let isrc = generateISRC()

            // 3. Save metadata to Firestore FIRST — the Content ID backend looks
            // up this doc to verify ownership (artistId == caller), so it must
            // exist before registerMusicTrack is called below.
            let trackData: [String: Any] = [
                "id": trackId,
                "title": trackTitle.trimmingCharacters(in: .whitespaces),
                "artistId": artistId,
                "artistName": artistName.trimmingCharacters(in: .whitespaces),
                "featuredArtists": featuredArtists.trimmingCharacters(in: .whitespaces),
                "album": albumName.trimmingCharacters(in: .whitespaces),
                "albumName": albumName.trimmingCharacters(in: .whitespaces),
                "releaseType": releaseType,
                "genre": selectedGenre,
                "language": trackLanguage,
                "isExplicit": isExplicit,
                "artworkURL": artworkURLString as Any,
                "audioURL": audioDownloadURL,
                "streamURL": audioDownloadURL,
                "duration": capturedDuration,
                "isrc": isrc,
                "songwriter": songwriter.trimmingCharacters(in: .whitespaces),
                "producer": producer.trimmingCharacters(in: .whitespaces),
                "recordLabel": recordLabel.trimmingCharacters(in: .whitespaces),
                "copyrightOwner": copyrightOwner.isEmpty ? artistName.trimmingCharacters(in: .whitespaces) : copyrightOwner.trimmingCharacters(in: .whitespaces),
                "copyrightYear": copyrightYear,
                "lyrics": lyrics,
                "streamCount": 0,
                "likeCount": 0,
                "uploadedAt": FieldValue.serverTimestamp(),
                "createdAt": FieldValue.serverTimestamp(),
                "isPublished": !scheduleRelease,
                "status": scheduleRelease ? "scheduled" : "published",
                "scheduledRelease": scheduleRelease,
                "releaseDate": scheduleRelease ? Timestamp(date: releaseDate) : FieldValue.serverTimestamp(),
                "contentIdProtected": protectWithContentID,
                "contentIdPolicy": selectedContentPolicy.rawValue
            ]
            try await db.collection("music_tracks").document(trackId).setData(trackData)

            if protectWithContentID {
                let contentIDReferenceId = await ContentIDService.shared.registerMusicTrack(
                    trackId: trackId,
                    audioURL: audioDownloadURL,
                    policy: selectedContentPolicy
                )
                if let contentIDReferenceId {
                    try await db.collection("music_tracks").document(trackId).updateData([
                        "contentIdReferenceId": contentIDReferenceId
                    ])
                }
            }
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
