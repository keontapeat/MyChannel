import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct ArtistDashboardTrackOption: Identifiable, Hashable {
    let id: String
    let title: String
    let audioURL: String?
}

struct ArtistPayoutRequestSheet: View {
    let artistId: String
    let availableAmount: Double
    let payoutAccountConnected: Bool
    let onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMethod: String = "standard"
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Request payout")
                        .font(.system(size: 24, weight: .bold))
                    Text(payoutAccountConnected ? "Submit a real payout request for your current available balance." : "Connect your payout account before requesting withdrawals.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Available")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(currency(availableAmount))
                        .font(.system(size: 34, weight: .bold))
                    if availableAmount < 10.0 {
                        Text("Minimum payout: $10.00")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Payout speed")
                        .font(.system(size: 16, weight: .semibold))
                    ForEach(["standard", "instant"], id: \.self) { method in
                        Button {
                            selectedMethod = method
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(method == "instant" ? "Instant payout" : "Standard payout")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(method == "instant" ? "1-2 business days • 1.5% fee" : "5-7 business days • no fee")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedMethod == method ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedMethod == method ? AppTheme.Colors.primary : .secondary)
                            }
                            .padding(14)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Submit payout request")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .background(canSubmit ? AppTheme.Colors.primary : Color.gray, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canSubmit || isSubmitting)
            }
            .padding(20)
        }
        .navigationTitle("Payout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSubmit: Bool {
        payoutAccountConnected && availableAmount >= 10.0
    }

    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        #if canImport(FirebaseFirestore)
        do {
            let fee = selectedMethod == "instant" ? availableAmount * 0.015 : 0
            let netAmount = availableAmount - fee
            let requestId = UUID().uuidString
            
            // Write to music_payout_requests collection (backend-aligned schema)
            try await Firestore.firestore().collection("music_payout_requests").document(requestId).setData([
                "artistId": artistId,
                "creatorId": artistId,
                "requestId": requestId,
                "grossAmount": availableAmount,
                "platformFee": fee,
                "finalAmount": netAmount,
                "payoutType": selectedMethod,
                "payoutMethod": selectedMethod,
                "status": "pending",
                "source": "music_streaming",
                "currency": "usd",
                "requestedAt": FieldValue.serverTimestamp(),
                "createdAt": FieldValue.serverTimestamp()
            ])
            
            await MainActor.run {
                isSubmitting = false
                onSubmitted()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
        #else
        await MainActor.run {
            isSubmitting = false
            errorMessage = "Firestore is unavailable in this build."
        }
        #endif
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

struct MusicDistributionRequestSheet: View {
    let artistId: String
    let tracks: [ArtistDashboardTrackOption]
    let onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTrackId: String = ""
    @State private var selectedPlatforms: Set<String> = []
    @State private var releaseDate: Date = Date()
    @State private var preSaveLink: String = ""
    @State private var notes: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let supportedPlatforms = [
        "Spotify",
        "Apple Music",
        "YouTube Music",
        "Amazon Music",
        "TIDAL",
        "Deezer",
        "TikTok",
        "Instagram/Facebook"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Submit a real platform distribution request for an uploaded track.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Track")
                        .font(.system(size: 16, weight: .semibold))
                    if tracks.isEmpty {
                        Text("Upload a track first to distribute it.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        Picker("Track", selection: $selectedTrackId) {
                            ForEach(tracks) { track in
                                Text(track.title).tag(track.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Platforms")
                        .font(.system(size: 16, weight: .semibold))
                    ForEach(supportedPlatforms, id: \.self) { platform in
                        Button {
                            if selectedPlatforms.contains(platform) {
                                selectedPlatforms.remove(platform)
                            } else {
                                selectedPlatforms.insert(platform)
                            }
                        } label: {
                            HStack {
                                Text(platform)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: selectedPlatforms.contains(platform) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedPlatforms.contains(platform) ? AppTheme.Colors.primary : .secondary)
                            }
                            .padding(14)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                DatePicker("Release date", selection: $releaseDate, displayedComponents: .date)
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pre-save link (optional)")
                        .font(.system(size: 16, weight: .semibold))
                    TextField("https://distrokid.com/hyperfollow/...", text: $preSaveLink)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.system(size: 16, weight: .semibold))
                    TextEditor(text: $notes)
                        .frame(minHeight: 110)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Submit distribution")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .background(canSubmit ? AppTheme.Colors.primary : Color.gray, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canSubmit || isSubmitting)
            }
            .padding(20)
        }
        .navigationTitle("Distribution")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedTrackId.isEmpty {
                selectedTrackId = tracks.first?.id ?? ""
            }
        }
    }

    private var canSubmit: Bool {
        !selectedTrackId.isEmpty && !selectedPlatforms.isEmpty
    }

    private func submit() async {
        guard canSubmit, let track = tracks.first(where: { $0.id == selectedTrackId }) else { return }
        isSubmitting = true
        errorMessage = nil
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            for platform in selectedPlatforms {
                try await db.collection("music_distribution").document().setData([
                    "artistId": artistId,
                    "trackId": track.id,
                    "trackTitle": track.title,
                    "platform": platform,
                    "status": "pending_review",
                    "releaseDate": Timestamp(date: releaseDate),
                    "preSaveLink": preSaveLink.trimmingCharacters(in: .whitespacesAndNewlines),
                    "notes": notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    "submittedAt": FieldValue.serverTimestamp()
                ])
            }
            await MainActor.run {
                isSubmitting = false
                onSubmitted()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
        #else
        await MainActor.run {
            isSubmitting = false
            errorMessage = "Firestore is unavailable in this build."
        }
        #endif
    }
}

struct ArtistVerificationRequestSheet: View {
    let artistId: String
    let displayName: String
    let email: String
    let onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var legalName: String = ""
    @State private var stageName: String = ""
    @State private var socialLink: String = ""
    @State private var notes: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Submit a real artist verification request for review.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Group {
                    textField("Stage name", text: $stageName)
                    textField("Legal name", text: $legalName)
                    textField("Contact email", text: .constant(email), disabled: true)
                    textField("Official link", text: $socialLink)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.system(size: 16, weight: .semibold))
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Submit verification")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .background(canSubmit ? AppTheme.Colors.primary : Color.gray, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canSubmit || isSubmitting)
            }
            .padding(20)
        }
        .navigationTitle("Verification")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if stageName.isEmpty {
                stageName = displayName
            }
        }
    }

    private var canSubmit: Bool {
        !stageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !email.isEmpty
    }

    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        #if canImport(FirebaseFirestore)
        do {
            try await Firestore.firestore().collection("artist_verification").document(artistId).setData([
                "artistId": artistId,
                "displayName": stageName.trimmingCharacters(in: .whitespacesAndNewlines),
                "legalName": legalName.trimmingCharacters(in: .whitespacesAndNewlines),
                "email": email,
                "socialLink": socialLink.trimmingCharacters(in: .whitespacesAndNewlines),
                "notes": notes.trimmingCharacters(in: .whitespacesAndNewlines),
                "status": "submitted",
                "submittedAt": FieldValue.serverTimestamp()
            ], merge: true)
            await MainActor.run {
                isSubmitting = false
                onSubmitted()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
        #else
        await MainActor.run {
            isSubmitting = false
            errorMessage = "Firestore is unavailable in this build."
        }
        #endif
    }

    private func textField(_ title: String, text: Binding<String>, disabled: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            TextField(title, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(disabled)
                .padding(14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

struct ContentIDEnrollmentSheet: View {
    let artistId: String
    let artistName: String
    let tracks: [ArtistDashboardTrackOption]
    let defaultPolicy: ContentMatch.MatchPolicy
    let onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTrackId: String = ""
    @State private var selectedPolicy: ContentMatch.MatchPolicy
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(artistId: String, artistName: String, tracks: [ArtistDashboardTrackOption], defaultPolicy: ContentMatch.MatchPolicy, onSubmitted: @escaping () -> Void) {
        self.artistId = artistId
        self.artistName = artistName
        self.tracks = tracks
        self.defaultPolicy = defaultPolicy
        self.onSubmitted = onSubmitted
        _selectedPolicy = State(initialValue: defaultPolicy)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Register an uploaded track as a real Content ID reference.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                if eligibleTracks.isEmpty {
                    Text("Upload a track with audio first before enrolling it in Content ID.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    Picker("Track", selection: $selectedTrackId) {
                        ForEach(eligibleTracks) { track in
                            Text(track.title).tag(track.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Picker("Policy", selection: $selectedPolicy) {
                        Text("Track").tag(ContentMatch.MatchPolicy.track)
                        Text("Monetize").tag(ContentMatch.MatchPolicy.monetize)
                        Text("Block").tag(ContentMatch.MatchPolicy.block)
                        Text("Mute").tag(ContentMatch.MatchPolicy.mute)
                    }
                    .pickerStyle(.segmented)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Register reference")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .background(canSubmit ? AppTheme.Colors.primary : Color.gray, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canSubmit || isSubmitting)
            }
            .padding(20)
        }
        .navigationTitle("Content ID")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedTrackId.isEmpty {
                selectedTrackId = eligibleTracks.first?.id ?? ""
            }
        }
    }

    private var eligibleTracks: [ArtistDashboardTrackOption] {
        tracks.filter { ($0.audioURL ?? "").isEmpty == false }
    }

    private var canSubmit: Bool {
        !selectedTrackId.isEmpty
    }

    private func submit() async {
        guard let track = eligibleTracks.first(where: { $0.id == selectedTrackId }), let audioURL = track.audioURL else { return }
        isSubmitting = true
        errorMessage = nil
        let referenceId = await ContentIDService.shared.uploadReferenceFile(
            title: track.title,
            rightsholder: artistName,
            ownerId: artistId,
            sourceTrackId: track.id,
            videoURL: "",
            audioURL: audioURL,
            policy: selectedPolicy
        )
        await MainActor.run {
            isSubmitting = false
            if referenceId == nil {
                errorMessage = "Could not register this track for Content ID."
            } else {
                onSubmitted()
                dismiss()
            }
        }
    }
}

// MARK: - Artist Profile Edit Sheet
// Writes to the "artists" collection to align with backend artist profile service

struct ArtistProfileEditSheet: View {
    let artistId: String
    let currentDisplayName: String
    let onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var bio: String = ""
    @State private var website: String = ""
    @State private var instagram: String = ""
    @State private var twitter: String = ""
    @State private var tiktok: String = ""
    @State private var genres: String = ""
    @State private var location: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        Group {
                            textField("Bio", text: $bio, placeholder: "Tell fans about yourself...")
                            textField("Location", text: $location, placeholder: "e.g., Flint, MI")
                            textField("Genres", text: $genres, placeholder: "e.g., Hip-Hop, R&B")
                            
                            Text("Social Links")
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.top, 8)
                            
                            textField("Website", text: $website, placeholder: "https://...")
                            textField("Instagram", text: $instagram, placeholder: "@username")
                            textField("Twitter/X", text: $twitter, placeholder: "@username")
                            textField("TikTok", text: $tiktok, placeholder: "@username")
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                Spacer()
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Save Profile")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .background(AppTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(isSubmitting)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Edit Artist Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            await loadExistingProfile()
        }
    }

    private func textField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func loadExistingProfile() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        do {
            let doc = try await db.collection("artists").document(artistId).getDocument()
            let data = doc.data()
            await MainActor.run {
                bio = data?["bio"] as? String ?? ""
                website = data?["website"] as? String ?? ""
                location = data?["location"] as? String ?? ""
                genres = (data?["genres"] as? [String])?.joined(separator: ", ") ?? ""
                
                let socials = data?["socialLinks"] as? [String: String] ?? [:]
                instagram = socials["instagram"] ?? ""
                twitter = socials["twitter"] ?? ""
                tiktok = socials["tiktok"] ?? ""
                
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
        #else
        isLoading = false
        #endif
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        #if canImport(FirebaseFirestore)
        do {
            let genreArray = genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let socialLinks: [String: String] = [
                "instagram": instagram,
                "twitter": twitter,
                "tiktok": tiktok,
                "website": website
            ].filter { !$0.value.isEmpty }

            try await Firestore.firestore().collection("artists").document(artistId).setData([
                "artistId": artistId,
                "displayName": currentDisplayName,
                "bio": bio,
                "location": location,
                "genres": genreArray,
                "website": website,
                "socialLinks": socialLinks,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            await MainActor.run {
                isSubmitting = false
                onSubmitted()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
        #else
        await MainActor.run {
            isSubmitting = false
            errorMessage = "Firestore is unavailable in this build."
        }
        #endif
    }
}

// MARK: - Track Edit / Delete Sheet

struct TrackEditDeleteSheet: View {
    let trackId: String
    let artistId: String
    let onUpdated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var trackEditTitle = ""
    @State private var trackEditAlbum = ""
    @State private var trackEditGenre = "Hip-Hop"
    @State private var trackEditExplicit = false
    @State private var trackEditSongwriter = ""
    @State private var trackEditProducer = ""
    @State private var trackEditLyrics = ""
    @State private var isLoadingTrack = true
    @State private var isSavingTrack = false
    @State private var showDeleteConfirm = false
    @State private var isDeletingTrack = false
    @State private var trackEditError: String?

    private let editGenres = [
        "Hip-Hop", "R&B", "Pop", "Rock", "Electronic", "Country",
        "Afrobeats", "Latin", "Jazz", "Indie", "Gospel", "Trap",
        "Soul", "Drill", "Alternative", "Lo-Fi", "Michigan Rap"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoadingTrack {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 60)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        trackEditField("Title", text: $trackEditTitle)
                        trackEditField("Album", text: $trackEditAlbum)
                        HStack {
                            Text("Genre")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Picker("", selection: $trackEditGenre) {
                                ForEach(editGenres, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                        }
                        Toggle("Explicit Content", isOn: $trackEditExplicit)
                            .tint(AppTheme.Colors.primary)
                        trackEditField("Songwriter", text: $trackEditSongwriter)
                        trackEditField("Producer", text: $trackEditProducer)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lyrics")
                                .font(.system(size: 16, weight: .semibold))
                            TextEditor(text: $trackEditLyrics)
                                .frame(minHeight: 120)
                                .padding(10)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        if let err = trackEditError {
                            Text(err).font(.system(size: 13)).foregroundColor(.red)
                        }
                        Button {
                            Task { await commitTrackEdits() }
                        } label: {
                            Group {
                                if isSavingTrack { ProgressView().tint(.white) }
                                else { Text("Save Changes").font(.system(size: 16, weight: .semibold)) }
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .background(AppTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(isSavingTrack || trackEditTitle.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                if isDeletingTrack { ProgressView().tint(.red) }
                                else {
                                    Image(systemName: "trash")
                                    Text("Delete Track").font(.system(size: 16, weight: .semibold))
                                }
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(isDeletingTrack)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .confirmationDialog("Delete this track permanently?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { Task { await commitTrackDelete() } }
            }
        }
        .task { await loadTrackForEdit() }
    }

    private func trackEditField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 16, weight: .semibold))
            TextField(label, text: text)
                .padding(14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func loadTrackForEdit() async {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await Firestore.firestore().collection("music_tracks").document(trackId).getDocument()
            let d = doc.data() ?? [:]
            await MainActor.run {
                trackEditTitle = d["title"] as? String ?? ""
                trackEditAlbum = d["albumName"] as? String ?? d["album"] as? String ?? ""
                trackEditGenre = d["genre"] as? String ?? "Hip-Hop"
                trackEditExplicit = d["isExplicit"] as? Bool ?? false
                trackEditSongwriter = d["songwriter"] as? String ?? ""
                trackEditProducer = d["producer"] as? String ?? ""
                trackEditLyrics = d["lyrics"] as? String ?? ""
                isLoadingTrack = false
            }
        } catch { await MainActor.run { isLoadingTrack = false } }
        #else
        isLoadingTrack = false
        #endif
    }

    private func commitTrackEdits() async {
        isSavingTrack = true; trackEditError = nil
        #if canImport(FirebaseFirestore)
        do {
            try await Firestore.firestore().collection("music_tracks").document(trackId).updateData([
                "title": trackEditTitle.trimmingCharacters(in: .whitespaces),
                "albumName": trackEditAlbum.trimmingCharacters(in: .whitespaces),
                "album": trackEditAlbum.trimmingCharacters(in: .whitespaces),
                "genre": trackEditGenre,
                "isExplicit": trackEditExplicit,
                "songwriter": trackEditSongwriter.trimmingCharacters(in: .whitespaces),
                "producer": trackEditProducer.trimmingCharacters(in: .whitespaces),
                "lyrics": trackEditLyrics,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            await MainActor.run { isSavingTrack = false; onUpdated(); dismiss() }
        } catch { await MainActor.run { isSavingTrack = false; trackEditError = error.localizedDescription } }
        #else
        isSavingTrack = false; trackEditError = "Firestore unavailable."
        #endif
    }

    private func commitTrackDelete() async {
        isDeletingTrack = true
        #if canImport(FirebaseFirestore)
        do {
            try await Firestore.firestore().collection("music_tracks").document(trackId).delete()
            await MainActor.run { isDeletingTrack = false; onUpdated(); dismiss() }
        } catch { await MainActor.run { isDeletingTrack = false; trackEditError = error.localizedDescription } }
        #else
        isDeletingTrack = false
        #endif
    }
}


// ⚡ RevenueSplitsSheet + DSPArtistClaimingSheet extracted to ArtistDashboardSheets2.swift
