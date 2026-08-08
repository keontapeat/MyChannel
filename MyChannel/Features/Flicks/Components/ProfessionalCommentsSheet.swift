import SwiftUI

struct ProfessionalCommentsSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var newComment = ""
    @State private var comments: [RealTimeComment] = []
    @State private var likedCommentIds: Set<String> = []
    @State private var sortOption: CommentSortOption = .topComments
    @State private var isLoading = true
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var listener: Any?
    @FocusState private var isTextFieldFocused: Bool

    private let commentsService = CommentsFirestoreService.shared

    var sortedComments: [RealTimeComment] {
        switch sortOption {
        case .topComments:
            return comments.sorted { $0.likeCount > $1.likeCount }
        case .newest:
            return comments.sorted { $0.createdAt > $1.createdAt }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.2))
                    .frame(width: 50, height: 5)
                    .padding(.top, 12)

                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Comments")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Text("\(comments.count.formatted()) comments")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    Spacer()

                    // Sort picker
                    Picker("Sort", selection: $sortOption) {
                        ForEach(CommentSortOption.allCases, id: \.self) { option in
                            Text(option.pickerLabel).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)

                commentsList

                inputBar
            }
            .navigationBarHidden(true)
        }
        .onAppear { startListening() }
        .onDisappear { stopListening() }
    }

    @ViewBuilder
    private var commentsList: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView()
                    .tint(AppTheme.Colors.primary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if comments.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                Text("No comments yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Be the first to comment")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedComments) { comment in
                        ProfessionalCommentRow(
                            comment: comment,
                            isLiked: likedCommentIds.contains(comment.id),
                            onLike: { toggleLike(comment) }
                        )
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }

            Divider()
                .background(.gray.opacity(0.2))

            HStack(spacing: 16) {
                avatarView

                HStack(spacing: 16) {
                    TextField("Add a comment...", text: $newComment, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium))
                        .focused($isTextFieldFocused)
                        .lineLimit(1...4)
                        .disabled(isPosting)

                    if isPosting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Post") {
                            postComment()
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.primary, in: Capsule())
                        .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var avatarView: some View {
        if let urlString = appState.currentUser?.profileImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(AppTheme.Colors.primary)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(AppTheme.Colors.primary)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String((appState.currentUser?.displayName ?? "Y").prefix(1)))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
    }

    // MARK: - Data

    private func startListening() {
        listener = commentsService.listen(videoId: video.id) { fetched in
            withAnimation(.easeInOut(duration: 0.2)) {
                comments = fetched
                isLoading = false
            }
        }
        // Fallback so the spinner never hangs if there are simply no comments yet.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if isLoading { isLoading = false }
        }
    }

    private func stopListening() {
        commentsService.stop(listener: listener)
        listener = nil
    }

    private func postComment() {
        let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard appState.requireAuthentication(hint: "Sign in to comment.") else { return }
        guard let userId = appState.currentUser?.id else { return }

        errorMessage = nil
        isPosting = true
        isTextFieldFocused = false
        let textToPost = trimmed

        Task {
            do {
                try await commentsService.post(videoId: video.id, userId: userId, text: textToPost)
                await MainActor.run {
                    newComment = ""
                    isPosting = false
                    HapticManager.shared.impact(style: .medium)
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                    errorMessage = error.localizedDescription
                    HapticManager.shared.notification(type: .error)
                }
            }
        }
    }

    private func toggleLike(_ comment: RealTimeComment) {
        guard appState.requireAuthentication(hint: "Sign in to like comments.") else { return }
        guard let userId = appState.currentUser?.id else { return }

        let willLike = !likedCommentIds.contains(comment.id)
        withAnimation(AppTheme.AnimationPresets.bouncy) {
            if willLike {
                likedCommentIds.insert(comment.id)
            } else {
                likedCommentIds.remove(comment.id)
            }
        }
        HapticManager.shared.impact(style: .light)

        Task {
            await commentsService.toggleLike(
                videoId: video.id,
                commentId: comment.id,
                userId: userId,
                add: willLike
            )
        }
    }
}

struct ProfessionalCommentRow: View {
    let comment: RealTimeComment
    let isLiked: Bool
    let onLike: () -> Void
    @State private var showReplies = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                AsyncImage(url: URL(string: comment.author.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.8))
                        .overlay(
                            Text(String(comment.author.displayName.prefix(1)))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text("@\(comment.author.username)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        if comment.author.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.blue)
                        }

                        Text(comment.timeAgo)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textTertiary)

                        Spacer()
                    }

                    Text(comment.text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 24) {
                        Button(action: onLike) {
                            HStack(spacing: 8) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 16))
                                    .foregroundStyle(isLiked ? .red : AppTheme.Colors.textTertiary)

                                let displayCount = comment.likeCount + (isLiked ? 1 : 0)
                                if displayCount > 0 {
                                    Text("\(displayCount)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppTheme.Colors.textTertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.top, 6)
                }
            }

            if comment.replyCount > 0 {
                Button(action: { showReplies.toggle() }) {
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(AppTheme.Colors.primary.opacity(0.6))
                            .frame(width: 32, height: 2)
                            .cornerRadius(1)

                        Text("View \(comment.replyCount) replies")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primary)

                        Image(systemName: showReplies ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primary)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 56)
                .padding(.top, 12)

                if showReplies {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(comment.replies) { reply in
                            HStack(alignment: .top, spacing: 12) {
                                AsyncImage(url: URL(string: reply.author.profileImageURL ?? "")) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(AppTheme.Colors.primary.opacity(0.5))
                                        .overlay(
                                            Text(String(reply.author.displayName.prefix(1)))
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                        )
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("@\(reply.author.username)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppTheme.Colors.textPrimary)

                                    Text(reply.text)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                }

                                Spacer()
                            }
                            .padding(.leading, 56)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

#Preview {
    ProfessionalCommentsSheet(video: Video.sampleVideos[0])
        .environmentObject(AppState.shared)
        .preferredColorScheme(.dark)
}
