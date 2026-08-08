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
    @State private var revision = 0
    @State private var isLoadingSplits = true
    @State private var isSavingSplits = false
    @State private var splitsError: String?

    struct SplitEntry: Identifiable {
        let id = UUID()
        var artistId: String
        var name: String
        var role: String
        var basisPoints: Int
    }

    private let supportedRoles = [
        ("Primary Artist", "primary_artist"),
        ("Featured Artist", "featured_artist"),
        ("Producer", "producer"),
        ("Songwriter", "songwriter"),
        ("Composer", "composer"),
        ("Performer", "performer"),
        ("Label", "label"),
        ("Publisher", "publisher")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoadingSplits {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    splitsForm
                }
            }
            .navigationTitle("Revenue Splits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await loadExistingSplits() }
    }

    private var splitsForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Split royalties for \"\(trackTitle)\" using linked MyChannel user IDs.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            if revision > 0 {
                Text("Revision \(revision)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            ForEach(splits.indices, id: \.self) { index in
                splitEditor(at: index)
            }

            Button {
                splits.append(
                    SplitEntry(
                        artistId: "",
                        name: "",
                        role: "featured_artist",
                        basisPoints: 0
                    )
                )
            } label: {
                Label("Add Collaborator", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .disabled(splits.count >= 20)

            totalSection

            if let splitsError {
                Text(splitsError)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            }

            Button {
                Task { await commitSplitsSave() }
            } label: {
                Group {
                    if isSavingSplits {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save Splits")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .background(
                    splitsCanSave ? AppTheme.Colors.primary : Color.gray,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .disabled(!splitsCanSave || isSavingSplits)
        }
        .padding(20)
    }

    private func splitEditor(at index: Int) -> some View {
        let isOwner = splits[index].artistId == artistId
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isOwner ? "Track Owner" : "Collaborator \(index + 1)")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if !isOwner {
                    Button { splits.remove(at: index) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }

            TextField("Display name", text: $splits[index].name)
                .padding(14)
                .background(fieldBackground)

            if isOwner {
                Text(artistId)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(fieldBackground)
            } else {
                TextField("Linked MyChannel user ID", text: $splits[index].artistId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(fieldBackground)
            }

            HStack {
                Picker("Role", selection: $splits[index].role) {
                    ForEach(supportedRoles, id: \.1) { role in
                        Text(role.0).tag(role.1)
                    }
                }
                .pickerStyle(.menu)
                .disabled(isOwner)

                Spacer()

                TextField("0", value: $splits[index].basisPoints, format: .number)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .padding(10)
                    .background(fieldBackground)
                Text("bp")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(
            Color(.secondarySystemBackground).opacity(0.5),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var fieldBackground: some ShapeStyle {
        Color(.secondarySystemBackground)
    }

    private var totalSection: some View {
        let totalBasisPoints = splits.reduce(0) { $0 + $1.basisPoints }
        return HStack {
            Text("Total Split")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Text("\(totalBasisPoints) / 10,000 bp")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(totalBasisPoints == 10_000 ? .green : .red)
        }
        .padding(14)
        .background(fieldBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var splitsCanSave: Bool {
        guard (1...20).contains(splits.count),
              splits.reduce(0, { $0 + $1.basisPoints }) == 10_000,
              splits.contains(where: {
                  $0.artistId == artistId && $0.role == "primary_artist"
              }) else { return false }

        let identifiers = splits.map(\.artistId)
        return Set(identifiers).count == identifiers.count && splits.allSatisfy { split in
            isSafeIdentifier(split.artistId) &&
                !split.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                (1...10_000).contains(split.basisPoints) &&
                supportedRoles.contains(where: { $0.1 == split.role })
        }
    }

    private func loadExistingSplits() async {
        do {
            let response = try await MusicAPIClient.shared.getCollaborators(trackId: trackId)
            var loaded = response.collaborators.map {
                SplitEntry(
                    artistId: $0.artistId,
                    name: $0.name,
                    role: $0.role,
                    basisPoints: $0.basisPoints
                )
            }
            if loaded.isEmpty {
                loaded = [ownerEntry(basisPoints: 10_000)]
            } else if let ownerIndex = loaded.firstIndex(where: { $0.artistId == artistId }) {
                loaded[ownerIndex].role = "primary_artist"
                let owner = loaded.remove(at: ownerIndex)
                loaded.insert(owner, at: 0)
            } else {
                loaded.insert(ownerEntry(basisPoints: 0), at: 0)
            }
            splits = loaded
            revision = response.revision
            splitsError = nil
        } catch {
            splits = [ownerEntry(basisPoints: 10_000)]
            splitsError = error.localizedDescription
        }
        isLoadingSplits = false
    }

    private func commitSplitsSave() async {
        guard splitsCanSave else {
            splitsError = "Use unique linked user IDs and integer basis points totaling exactly 10,000."
            return
        }
        isSavingSplits = true
        splitsError = nil
        defer { isSavingSplits = false }

        do {
            let collaborators = splits.map {
                MusicCollaboratorInput(
                    artistId: $0.artistId,
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    role: $0.role,
                    basisPoints: $0.basisPoints
                )
            }
            let response = try await MusicAPIClient.shared.replaceCollaborators(
                trackId: trackId,
                collaborators: collaborators
            )
            revision = response.revision
            onSaved()
            dismiss()
        } catch {
            splitsError = error.localizedDescription
        }
    }

    private func ownerEntry(basisPoints: Int) -> SplitEntry {
        SplitEntry(
            artistId: artistId,
            name: "Primary Artist",
            role: "primary_artist",
            basisPoints: basisPoints
        )
    }

    private func isSafeIdentifier(_ value: String) -> Bool {
        value.range(
            of: #"^[A-Za-z0-9_-]{1,128}$"#,
            options: .regularExpression
        ) != nil
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
