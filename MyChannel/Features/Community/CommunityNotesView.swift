//
//  CommunityNotesView.swift
//  MyChannel
//
//  YouTube-parity Community Notes — viewers can add context to videos,
//  rate existing notes as helpful/unhelpful, and see top-rated notes
//  displayed below the player chrome (feature-flagged by enableCommunityNotes).
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct ViewerCommunityNote: Identifiable, Codable {
    let id: String
    let videoId: String
    let authorId: String
    let authorName: String
    let text: String
    var helpfulVotes: Int
    var unhelpfulVotes: Int
    let createdAt: Date

    var helpfulnessScore: Double {
        let total = helpfulVotes + unhelpfulVotes
        guard total > 0 else { return 0 }
        return Double(helpfulVotes) / Double(total)
    }

    var isHighlyRated: Bool { helpfulnessScore >= 0.7 && helpfulVotes >= 5 }
}

@MainActor
final class CommunityNotesViewModel: ObservableObject {
    @Published var notes: [ViewerCommunityNote] = []
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var newNoteText = ""
    @Published var showAddNote = false
    @Published var error: String?

    private let videoId: String
    #if canImport(FirebaseFirestore)
    private var listener: ListenerRegistration?
    #endif

    init(videoId: String) {
        self.videoId = videoId
    }

    func startListening() {
        guard AppConfig.Features.enableCommunityNotes else { return }
        isLoading = true
        #if canImport(FirebaseFirestore)
        listener = Firestore.firestore()
            .collection("community-notes")
            .whereField("videoId", isEqualTo: videoId)
            .order(by: "helpfulVotes", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let fetched: [ViewerCommunityNote] = snapshot?.documents.compactMap { doc in
                    let d = doc.data()
                    return ViewerCommunityNote(
                        id: doc.documentID,
                        videoId: d["videoId"] as? String ?? "",
                        authorId: d["authorId"] as? String ?? "",
                        authorName: d["authorName"] as? String ?? "Community Member",
                        text: d["text"] as? String ?? "",
                        helpfulVotes: d["helpfulVotes"] as? Int ?? 0,
                        unhelpfulVotes: d["unhelpfulVotes"] as? Int ?? 0,
                        createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                } ?? []
                Task { @MainActor in
                    self.notes = fetched
                    self.isLoading = false
                }
            }
        #endif
    }

    func stopListening() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        #endif
    }

    func submitNote() async {
        let text = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count >= 20 else {
            error = "Note must be at least 20 characters."
            return
        }
        guard let user = AppState.shared.currentUser else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        #if canImport(FirebaseFirestore)
        let data: [String: Any] = [
            "videoId": videoId,
            "authorId": user.id,
            "authorName": user.displayName,
            "text": text,
            "helpfulVotes": 0,
            "unhelpfulVotes": 0,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try? await Firestore.firestore()
            .collection("community-notes")
            .addDocument(data: data)
        #endif
        newNoteText = ""
        showAddNote = false
    }

    func vote(note: ViewerCommunityNote, helpful: Bool) async {
        guard AppState.shared.currentUser != nil else { return }
        #if canImport(FirebaseFirestore)
        let field = helpful ? "helpfulVotes" : "unhelpfulVotes"
        try? await Firestore.firestore()
            .collection("community-notes")
            .document(note.id)
            .updateData([field: FieldValue.increment(Int64(1))])
        #endif
    }
}

struct CommunityNotesView: View {
    let videoId: String
    @StateObject private var vm: CommunityNotesViewModel

    init(videoId: String) {
        self.videoId = videoId
        _vm = StateObject(wrappedValue: CommunityNotesViewModel(videoId: videoId))
    }

    var body: some View {
        guard AppConfig.Features.enableCommunityNotes else { return AnyView(EmptyView()) }
        return AnyView(content)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if vm.isLoading {
                HStack { ProgressView().padding() }
            } else if !vm.notes.isEmpty {
                // Show the top-rated note inline
                if let topNote = vm.notes.first(where: { $0.isHighlyRated }) ?? vm.notes.first {
                    topNoteCard(topNote)
                }
                if vm.notes.count > 1 {
                    Button {
                        // Navigate to full notes list
                    } label: {
                        Text("See all \(vm.notes.count) notes")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }

            // Add a note button
            Button {
                vm.showAddNote = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 14))
                    Text("Add context")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .onAppear { vm.startListening() }
        .onDisappear { vm.stopListening() }
        .sheet(isPresented: $vm.showAddNote) {
            addNoteSheet
        }
    }

    private func topNoteCard(_ note: ViewerCommunityNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                Text("Community Note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
                Spacer()
                Text("\(note.helpfulVotes) found helpful")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }

            Text(note.text)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(4)

            HStack(spacing: 16) {
                Button {
                    Task { await vm.vote(note: note, helpful: true) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup")
                            .font(.system(size: 12))
                        Text("Helpful")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                Button {
                    Task { await vm.vote(note: note, helpful: false) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsdown")
                            .font(.system(size: 12))
                        Text("Not helpful")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                Spacer()
            }
        }
        .padding(14)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var addNoteSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add context that other viewers might find helpful. Notes are reviewed by the community before being shown.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 20)

                TextEditor(text: $vm.newNoteText)
                    .font(.system(size: 15))
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Colors.divider, lineWidth: 1))
                    .padding(.horizontal, 20)

                HStack {
                    Spacer()
                    Text("\(vm.newNoteText.count)/500")
                        .font(.system(size: 12))
                        .foregroundColor(vm.newNoteText.count > 500 ? .red : AppTheme.Colors.textTertiary)
                        .padding(.horizontal, 20)
                }

                if let err = vm.error {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                }

                Spacer()
            }
            .navigationTitle("Add Community Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { vm.showAddNote = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        Task { await vm.submitNote() }
                    }
                    .disabled(vm.newNoteText.count < 20 || vm.isSubmitting)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    CommunityNotesView(videoId: "video123")
}
