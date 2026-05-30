// ⚡ PERFORMANCE: Extracted from ArtistDashboardSupportViews.swift — independent compilation unit.
// RevenueSplitsSheet and DSPArtistClaimingSheet compile in parallel with the first 6 sheets.
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Revenue Splits Sheet

struct RevenueSplitsSheet: View {
    let trackId: String
    let trackTitle: String
    let artistId: String
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var splits: [SplitEntry] = []
    @State private var isSavingSplits = false
    @State private var splitsError: String?

    struct SplitEntry: Identifiable {
        let id = UUID()
        var name: String
        var email: String
        var role: String
        var percentage: Double
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Split royalties for \"\(trackTitle)\" with collaborators.")
                        .font(.system(size: 14)).foregroundColor(.secondary)

                    ForEach(splits.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Collaborator \(i + 1)").font(.system(size: 16, weight: .semibold))
                                Spacer()
                                if splits.count > 1 {
                                    Button { splits.remove(at: i) } label: {
                                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                    }
                                }
                            }
                            TextField("Name", text: $splits[i].name)
                                .padding(14)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            TextField("Email", text: $splits[i].email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .padding(14)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            HStack {
                                Picker("Role", selection: $splits[i].role) {
                                    Text("Artist").tag("artist")
                                    Text("Producer").tag("producer")
                                    Text("Songwriter").tag("songwriter")
                                    Text("Featured").tag("featured")
                                }
                                .pickerStyle(.menu)
                                Spacer()
                                HStack(spacing: 4) {
                                    TextField("0", value: $splits[i].percentage, format: .number)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 60)
                                        .multilineTextAlignment(.trailing)
                                        .padding(10)
                                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    Text("%").font(.system(size: 15, weight: .semibold)).foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground).opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        splits.append(SplitEntry(name: "", email: "", role: "artist", percentage: 0))
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Collaborator").font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(AppTheme.Colors.primary)
                    }

                    let totalPct = splits.reduce(0) { $0 + $1.percentage }
                    HStack {
                        Text("Total Split").font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text("\(String(format: "%.1f", totalPct))%")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(abs(totalPct - 100) < 0.01 ? .green : .red)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if abs(totalPct - 100) > 0.01 {
                        Text("Splits must total exactly 100%").font(.system(size: 13)).foregroundColor(.red)
                    }
                    if let splitsError {
                        Text(splitsError).font(.system(size: 13)).foregroundColor(.red)
                    }

                    Button {
                        Task { await commitSplitsSave() }
                    } label: {
                        Group {
                            if isSavingSplits { ProgressView().tint(.white) }
                            else { Text("Save Splits").font(.system(size: 16, weight: .semibold)) }
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .background(splitsCanSave ? AppTheme.Colors.primary : Color.gray, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(!splitsCanSave || isSavingSplits)
                }
                .padding(20)
            }
            .navigationTitle("Revenue Splits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .task { await loadExistingSplits() }
    }

    private var splitsCanSave: Bool {
        let t = splits.reduce(0) { $0 + $1.percentage }
        return abs(t - 100) < 0.01 && splits.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func loadExistingSplits() async {
        #if canImport(FirebaseFirestore)
        do {
            let docs = try await Firestore.firestore().collection("music_tracks").document(trackId)
                .collection("splits").getDocuments()
            let loaded = docs.documents.compactMap { doc -> SplitEntry? in
                let d = doc.data()
                return SplitEntry(name: d["name"] as? String ?? "", email: d["email"] as? String ?? "",
                                  role: d["role"] as? String ?? "artist", percentage: d["percentage"] as? Double ?? 0)
            }
            await MainActor.run {
                splits = loaded.isEmpty ? [SplitEntry(name: "", email: "", role: "artist", percentage: 100)] : loaded
            }
        } catch {
            await MainActor.run { splits = [SplitEntry(name: "", email: "", role: "artist", percentage: 100)] }
        }
        #else
        splits = [SplitEntry(name: "", email: "", role: "artist", percentage: 100)]
        #endif
    }

    private func commitSplitsSave() async {
        guard splitsCanSave else { return }
        isSavingSplits = true; splitsError = nil
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let ref = db.collection("music_tracks").document(trackId).collection("splits")
            for doc in try await ref.getDocuments().documents { try await ref.document(doc.documentID).delete() }
            for split in splits {
                try await ref.document().setData([
                    "name": split.name.trimmingCharacters(in: .whitespaces),
                    "email": split.email.trimmingCharacters(in: .whitespaces),
                    "role": split.role, "percentage": split.percentage,
                    "trackId": trackId, "artistId": artistId,
                    "createdAt": FieldValue.serverTimestamp()
                ])
            }
            try await db.collection("music_tracks").document(trackId).updateData([
                "hasSplits": true, "splitCount": splits.count
            ])
            await MainActor.run { isSavingSplits = false; onSaved(); dismiss() }
        } catch { await MainActor.run { isSavingSplits = false; splitsError = error.localizedDescription } }
        #else
        isSavingSplits = false; splitsError = "Firestore unavailable."
        #endif
    }
}

// MARK: - DSP Artist Claiming Sheet

struct DSPArtistClaimingSheet: View {
    let artistId: String
    let artistName: String
    let onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var spotifyURL = ""
    @State private var appleMusicURL = ""
    @State private var youtubeMusicURL = ""
    @State private var isSavingDSP = false
    @State private var dspError: String?
    @State private var isLoadingDSP = true

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoadingDSP {
                    ProgressView().frame(maxWidth: .infinity, alignment: .center).padding(.top, 60)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Link your artist profiles on streaming platforms so fans can find your official pages.")
                            .font(.system(size: 14)).foregroundColor(.secondary)

                        dspLinkRow(platform: "Spotify for Artists", icon: "music.note", color: .green,
                                   placeholder: "https://open.spotify.com/artist/...", text: $spotifyURL)
                        dspLinkRow(platform: "Apple Music for Artists", icon: "music.note", color: .red,
                                   placeholder: "https://music.apple.com/artist/...", text: $appleMusicURL)
                        dspLinkRow(platform: "YouTube Music", icon: "play.rectangle.fill", color: .red,
                                   placeholder: "https://music.youtube.com/channel/...", text: $youtubeMusicURL)

                        if let dspError {
                            Text(dspError).font(.system(size: 13)).foregroundColor(.red)
                        }

                        Button {
                            Task { await commitDSPSave() }
                        } label: {
                            Group {
                                if isSavingDSP { ProgressView().tint(.white) }
                                else { Text("Save Profiles").font(.system(size: 16, weight: .semibold)) }
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .background(AppTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(isSavingDSP)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Why claim your profiles?").font(.system(size: 14, weight: .semibold))
                            Text("• Get verified badges on streaming platforms\n• Access platform-specific analytics\n• Customize your artist page\n• Pitch to editorial playlists")
                                .font(.system(size: 13)).foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Claim Artist Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .task { await loadDSPData() }
    }

    private func dspLinkRow(platform: String, icon: String, color: Color, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
                Text(platform).font(.system(size: 16, weight: .semibold))
            }
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func loadDSPData() async {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await Firestore.firestore().collection("artists").document(artistId).getDocument()
            let dsp = (doc.data() ?? [:])["dspProfiles"] as? [String: String] ?? [:]
            await MainActor.run {
                spotifyURL = dsp["spotify"] ?? ""
                appleMusicURL = dsp["appleMusic"] ?? ""
                youtubeMusicURL = dsp["youtubeMusic"] ?? ""
                isLoadingDSP = false
            }
        } catch { await MainActor.run { isLoadingDSP = false } }
        #else
        isLoadingDSP = false
        #endif
    }

    private func commitDSPSave() async {
        isSavingDSP = true; dspError = nil
        #if canImport(FirebaseFirestore)
        do {
            let dsp: [String: String] = [
                "spotify": spotifyURL.trimmingCharacters(in: .whitespacesAndNewlines),
                "appleMusic": appleMusicURL.trimmingCharacters(in: .whitespacesAndNewlines),
                "youtubeMusic": youtubeMusicURL.trimmingCharacters(in: .whitespacesAndNewlines)
            ].filter { !$0.value.isEmpty }
            try await Firestore.firestore().collection("artists").document(artistId).setData([
                "dspProfiles": dsp, "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            await MainActor.run { isSavingDSP = false; onSubmitted(); dismiss() }
        } catch { await MainActor.run { isSavingDSP = false; dspError = error.localizedDescription } }
        #else
        isSavingDSP = false; dspError = "Firestore unavailable."
        #endif
    }
}
