import SwiftUI

struct ProfessionalCommentsSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var newComment = ""
    @State private var comments: [VideoComment] = []
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
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
                        
                        Text("\(video.commentCount.formatted()) comments")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
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
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(comments) { comment in
                            ProfessionalCommentRow(comment: comment)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(.ultraThinMaterial.opacity(0.3))
                        }
                    }
                }
                
                VStack(spacing: 0) {
                    Divider()
                        .background(.gray.opacity(0.2))
                    
                    HStack(spacing: 16) {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text("Y")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        HStack(spacing: 16) {
                            TextField("Add a thoughtful comment...", text: $newComment, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15, weight: .medium))
                                .focused($isTextFieldFocused)
                                .lineLimit(1...4)
                            
                            if !newComment.isEmpty {
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
            .navigationBarHidden(true)
        }
        .onAppear {
            loadComments()
        }
    }
    
    private func loadComments() {
        comments = VideoComment.sampleComments
    }
    
    private func postComment() {
        guard !newComment.isEmpty else { return }
        
        let comment = VideoComment(
            author: User.sampleUsers[0],
            text: newComment,
            likeCount: 0,
            replyCount: 0,
            createdAt: Date()
        )
        
        withAnimation(AppTheme.AnimationPresets.spring) {
            comments.insert(comment, at: 0)
        }
        
        newComment = ""
        isTextFieldFocused = false
        HapticManager.shared.impact(style: .medium)
    }
}

struct ProfessionalCommentRow: View {
    let comment: VideoComment
    @State private var isLiked = false
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
                        
                        Text(comment.timeAgo)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                        
                        Spacer()
                        
                        Button(action: { }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(comment.text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 24) {
                        Button(action: { toggleLike() }) {
                            HStack(spacing: 8) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 16))
                                    .foregroundStyle(isLiked ? .red : AppTheme.Colors.textTertiary)
                                
                                if comment.likeCount > 0 {
                                    Text("\(comment.likeCount)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppTheme.Colors.textTertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { }) {
                            Text("Reply")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.primary)
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
            }
        }
    }
    
    private func toggleLike() {
        withAnimation(AppTheme.AnimationPresets.bouncy) {
            isLiked.toggle()
        }
        HapticManager.shared.impact(style: .light)
    }
}

#Preview {
    ProfessionalCommentsSheet(video: Video.sampleVideos[0])
        .preferredColorScheme(.dark)
}