//
//  ArtistTrackCommentSheet.swift
//  MyChannel
//
//  Comments + likes sheet for creator-uploaded tracks.
//  Reads/writes music_tracks/{id}/comments subcollection.
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

// MARK: - Comment Model

struct TrackComment: Identifiable {
    let id: String
    let userId: String
    let displayName: String
    let text: String
    let createdAt: Date
}

// MARK: - Sheet View

struct ArtistTrackCommentSheet: View {
    let track: UploadedTrack
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [TrackComment] = []
    @State private var newText: String = ""
    @State private var isLoading = true
    @State private var isSending = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Track info header
                trackHeader
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                Divider()

                // Comments list
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if comments.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("Be the first to comment")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(comments) { comment in
                                commentRow(comment)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                }

                Divider()

                // Input bar
                inputBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 0.88, green: 0.15, blue: 0.25))
                }
            }
        }
        .task { await loadComments() }
    }

    // MARK: - Track Header

    private var trackHeader: some View {
        HStack(spacing: 12) {
            Group {
                if let urlStr = track.artworkURL, let url = URL(string: urlStr) {
                    AppAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { placeholderArt }
                } else {
                    placeholderArt
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.88, green: 0.15, blue: 0.25))
                Text("\(track.likeCount)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var placeholderArt: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.88, green: 0.15, blue: 0.25), Color(red: 0.58, green: 0.08, blue: 0.38)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Comment Row

    private func commentRow(_ comment: TrackComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(red: 0.88, green: 0.15, blue: 0.25).opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(comment.displayName.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.88, green: 0.15, blue: 0.25))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.displayName)
                        .font(.system(size: 13, weight: .semibold))
                    Text(timeAgo(comment.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Add a comment...", text: $newText, axis: .vertical)
                .font(.system(size: 14))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .lineLimit(1...4)
                .focused($inputFocused)

            Button {
                Task { await postComment() }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            newText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.secondary.opacity(0.2)
                            : Color(red: 0.88, green: 0.15, blue: 0.25)
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
    }

    // MARK: - Data

    private func loadComments() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        do {
            let snap = try await db
                .collection("music_tracks").document(track.id)
                .collection("comments")
                .order(by: "createdAt", descending: false)
                .limit(to: 100)
                .getDocuments()
            comments = snap.documents.compactMap { doc -> TrackComment? in
                let d = doc.data()
                guard let text = d["text"] as? String,
                      let uid = d["userId"] as? String,
                      let name = d["displayName"] as? String else { return nil }
                let ts = (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                return TrackComment(id: doc.documentID, userId: uid, displayName: name, text: text, createdAt: ts)
            }
        } catch {
            print("❌ [Comments] load error: \(error)")
        }
        #endif
        isLoading = false
    }

    private func postComment() async {
        let text = newText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSending = true
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        let uid = Auth.auth().currentUser?.uid ?? UUID().uuidString
        let name = Auth.auth().currentUser?.displayName ?? "Listener"
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "userId": uid,
            "displayName": name,
            "text": text,
            "createdAt": FieldValue.serverTimestamp()
        ]
        do {
            let ref = try await db
                .collection("music_tracks").document(track.id)
                .collection("comments")
                .addDocument(data: data)
            let local = TrackComment(id: ref.documentID, userId: uid, displayName: name, text: text, createdAt: Date())
            await MainActor.run { comments.append(local) }
        } catch {
            print("❌ [Comments] post error: \(error)")
        }
        #else
        let local = TrackComment(id: UUID().uuidString, userId: "me", displayName: "You", text: text, createdAt: Date())
        comments.append(local)
        #endif
        newText = ""
        inputFocused = false
        isSending = false
    }

    // MARK: - Helpers

    private func timeAgo(_ date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "now" }
        if diff < 3600 { return "\(diff / 60)m" }
        if diff < 86400 { return "\(diff / 3600)h" }
        return "\(diff / 86400)d"
    }
}
