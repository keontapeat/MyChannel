//
//  RealTimeCommentsView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct RealTimeCommentsView: View {
    let video: Video
    @StateObject private var commentsManager = RealTimeCommentsManager()
    @State private var newCommentText = ""
    @State private var showingCommentComposer = false
    @State private var selectedComment: RealTimeComment?
    @State private var sortOption: RealTimeCommentSortOption = .newest
    
    
    enum RealTimeCommentSortOption: String, CaseIterable {
        case newest = "Newest"
        case popular = "Popular"
        case oldest = "Oldest"
        
        var systemImage: String {
            switch self {
            case .newest: return "clock"
            case .popular: return "heart.fill"
            case .oldest: return "clock.arrow.circlepath"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            commentsHeader
            
            // Comments list
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(sortedComments) { comment in
                        RealTimeCommentRow(
                            comment: comment,
                            onLike: { commentId in
                                commentsManager.toggleLike(commentId: commentId)
                            },
                            onReply: { comment in
                                selectedComment = comment
                                showingCommentComposer = true
                            },
                            onReport: { commentId in
                                commentsManager.reportComment(commentId: commentId)
                            },
                            canPin: AppState.shared.currentUser?.id == video.creatorId,
                            isPinned: commentsManager.pinnedCommentId == comment.id,
                            onPin: { commentsManager.pin(commentId: comment.id) },
                            onUnpin: { commentsManager.unpin() }
                        )
                        .padding(.horizontal)
                    }
                    
                    if commentsManager.isLoading {
                        ProgressView()
                            .padding()
                    }
                }
            }
            .refreshable {
                await commentsManager.refreshComments(for: video.id)
            }
            
            // Add comment bar
            addCommentBar
        }
        .background(AppTheme.Colors.background)
        .onAppear {
            commentsManager.startListening(to: video.id)
        }
        .onDisappear {
            commentsManager.stopListening()
        }
        .sheet(isPresented: $showingCommentComposer) {
            CommentComposerSheet(
                video: video,
                replyingTo: selectedComment
            ) { newComment in
                commentsManager.addComment(newComment)
                selectedComment = nil
            }
        }
    }
    
    // MARK: - Comments Header
    private var commentsHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Comments")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("•")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("\(commentsManager.comments.count)")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                // Sort menu
                Menu {
                    ForEach(RealTimeCommentSortOption.allCases, id: \.self) { option in
                        Button(action: { sortOption = option }) {
                            Label(option.rawValue, systemImage: option.systemImage)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: sortOption.systemImage)
                        Text(sortOption.rawValue)
                    }
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal)
            
            Divider()
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Add Comment Bar
    private var addCommentBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // User avatar
                AsyncImage(url: URL(string: AppState.shared.currentUser?.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .overlay(
                            Text(String(AppState.shared.currentUser?.displayName.prefix(1) ?? "?"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                
                // Comment input
                Button(action: { showingCommentComposer = true }) {
                    HStack {
                        Text("Add a comment...")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(AppTheme.Colors.background)
        }
    }
    
    // MARK: - Sorted Comments
    private var sortedComments: [RealTimeComment] {
        switch sortOption {
        case .newest:
            return commentsManager.comments.sorted { $0.createdAt > $1.createdAt }
        case .popular:
            return commentsManager.comments.sorted { $0.likeCount > $1.likeCount }
        case .oldest:
            return commentsManager.comments.sorted { $0.createdAt < $1.createdAt }
        }
    }
}

// MARK: - Real Time Comment Row
struct RealTimeCommentRow: View {
    let comment: RealTimeComment
    let onLike: (String) -> Void
    let onReply: (RealTimeComment) -> Void
    let onReport: (String) -> Void
    var canPin: Bool = false
    var isPinned: Bool = false
    var onPin: (() -> Void)? = nil
    var onUnpin: (() -> Void)? = nil
    
    @State private var isLiked = false
    @State private var showingReplies = false
    @State private var showingMoreOptions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Author avatar
                AsyncImage(url: URL(string: comment.author.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Text(String(comment.author.displayName.prefix(1)))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        )
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 8) {
                    // Comment header
                    HStack(spacing: 6) {
                        Text(comment.author.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if comment.author.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        
                        Text(comment.timeAgo)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        if comment.isEdited {
                            Text("(edited)")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        
                        Spacer()
                        if isPinned {
                            Label("Pinned", systemImage: "pin.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(AppTheme.Colors.surface)
                                .clipShape(Capsule())
                        }
                        
                        Button(action: { showingMoreOptions = true }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                    }
                    
                    // 🔥 YOUTUBE PARITY: Comment text with clickable timestamps, @mentions, #hashtags
                    RichCommentText(text: comment.text) { timestamp in
                        // Seek video to timestamp
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SeekToTimestamp"),
                            object: timestamp
                        )
                    }
                    
                    // Comment actions
                    HStack(spacing: 16) {
                        Button(action: {
                            isLiked.toggle()
                            onLike(comment.id)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 14))
                                    .foregroundColor(isLiked ? .red : AppTheme.Colors.textTertiary)
                                
                                if comment.likeCount > 0 {
                                    Text("\(comment.likeCount)")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                }
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                        
                        Button("Reply") {
                            onReply(comment)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Spacer()
                        
                        // Live indicator for real-time comments
                        if comment.isLive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(1.0)
                                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: UUID())
                                
                                Text("LIVE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // Show replies
                    if comment.replyCount > 0 {
                        Button(action: { showingReplies.toggle() }) {
                            HStack(spacing: 6) {
                                Image(systemName: showingReplies ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.primary)
                                
                                Text("\(comment.replyCount) replies")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        
                        if showingReplies && !comment.replies.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(comment.replies.prefix(3)) { reply in
                                    ReplyRow(reply: reply)
                                }
                                
                                if comment.replies.count > 3 {
                                    Button("Show \(comment.replies.count - 3) more replies") {
                                        // Show all replies
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                            .padding(.leading, 20)
                        }
                    }
                }
            }
        }
        .confirmationDialog("Comment Options", isPresented: $showingMoreOptions) {
            if canPin {
                if isPinned {
                    Button("Unpin") { onUnpin?() }
                } else {
                    Button("Pin") { onPin?() }
                }
            }
            Button("Report") { onReport(comment.id) }
            Button("Copy") { UIPasteboard.general.string = comment.text }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// 🔥 YOUTUBE PARITY: Rich comment text with clickable timestamps, @mentions, #hashtags
struct RichCommentText: View {
    let text: String
    let onTimestampTap: ((TimeInterval) -> Void)?
    
    init(text: String, onTimestampTap: ((TimeInterval) -> Void)? = nil) {
        self.text = text
        self.onTimestampTap = onTimestampTap
    }
    
    var body: some View {
        parseAndDisplayComment()
    }
    
    @ViewBuilder
    private func parseAndDisplayComment() -> some View {
        let segments = parseComment(text)
        
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                switch segment.type {
                case .timestamp:
                    if let time = segment.timestamp {
                        Button(action: {
                            onTimestampTap?(time)
                        }) {
                            Text(segment.text)
                                .foregroundColor(AppTheme.Colors.primary)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(segment.text)
                            .foregroundColor(AppTheme.Colors.primary)
                            .fontWeight(.medium)
                    }
                    
                case .mention:
                    Text(segment.text)
                        .foregroundColor(AppTheme.Colors.primary)
                        .fontWeight(.medium)
                    
                case .hashtag:
                    Text(segment.text)
                        .foregroundColor(AppTheme.Colors.primary)
                        .fontWeight(.medium)
                    
                case .plain:
                    Text(segment.text)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
        }
        .font(.system(size: 14))
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func parseComment(_ text: String) -> [CommentSegment] {
        var segments: [CommentSegment] = []
        var currentIndex = text.startIndex
        
        // Regex patterns
        let timestampPattern = #"(\d{1,2}):(\d{2})(?::(\d{2}))?"#  // Timestamps: 1:23 or 1:23:45
        let mentionPattern = #"@([a-zA-Z0-9_.-]+)"#  // @mentions
        let hashtagPattern = #"#([a-zA-Z0-9_]+)"#  // #hashtags
        
        var matches: [(range: Range<String.Index>, type: CommentSegmentType, timestamp: TimeInterval?)] = []
        
        // Find timestamps
        if let timestampRegex = try? NSRegularExpression(pattern: timestampPattern, options: []) {
            let nsString = text as NSString
            let results = timestampRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for result in results {
                if let range = Range(result.range, in: text) {
                    let timestampText = String(text[range])
                    if let time = parseTimestamp(timestampText) {
                        matches.append((range: range, type: .timestamp, timestamp: time))
                    }
                }
            }
        }
        
        // Find @mentions
        if let mentionRegex = try? NSRegularExpression(pattern: mentionPattern, options: []) {
            let nsString = text as NSString
            let results = mentionRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for result in results {
                if let range = Range(result.range, in: text) {
                    matches.append((range: range, type: .mention, timestamp: nil))
                }
            }
        }
        
        // Find #hashtags
        if let hashtagRegex = try? NSRegularExpression(pattern: hashtagPattern, options: []) {
            let nsString = text as NSString
            let results = hashtagRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for result in results {
                if let range = Range(result.range, in: text) {
                    matches.append((range: range, type: .hashtag, timestamp: nil))
                }
            }
        }
        
        // Sort matches by position
        matches.sort { $0.range.lowerBound < $1.range.lowerBound }
        
        // Build segments
        for match in matches {
            if currentIndex < match.range.lowerBound {
                let plainText = String(text[currentIndex..<match.range.lowerBound])
                if !plainText.isEmpty {
                    segments.append(CommentSegment(text: plainText, type: .plain))
                }
            }
            
            let matchText = String(text[match.range])
            segments.append(CommentSegment(text: matchText, type: match.type, timestamp: match.timestamp))
            
            currentIndex = match.range.upperBound
        }
        
        if currentIndex < text.endIndex {
            let plainText = String(text[currentIndex...])
            if !plainText.isEmpty {
                segments.append(CommentSegment(text: plainText, type: .plain))
            }
        }
        
        if segments.isEmpty {
            segments.append(CommentSegment(text: text, type: .plain))
        }
        
        return segments
    }
    
    private func parseTimestamp(_ text: String) -> TimeInterval? {
        let components = text.split(separator: ":").compactMap { Int($0) }
        
        if components.count == 2 {
            return TimeInterval(components[0] * 60 + components[1])
        } else if components.count == 3 {
            return TimeInterval(components[0] * 3600 + components[1] * 60 + components[2])
        }
        
        return nil
    }
}

struct CommentSegment {
    let text: String
    let type: CommentSegmentType
    let timestamp: TimeInterval?
    
    init(text: String, type: CommentSegmentType, timestamp: TimeInterval? = nil) {
        self.text = text
        self.type = type
        self.timestamp = timestamp
    }
}

enum CommentSegmentType {
    case plain
    case timestamp
    case mention
    case hashtag
}

// MARK: - Reply Row
struct ReplyRow: View {
    let reply: CommentReply
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(AppTheme.Colors.divider)
                .frame(width: 1, height: 20)
            
            AsyncImage(url: URL(string: reply.author.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(AppTheme.Colors.surface)
            }
            .frame(width: 24, height: 24)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(reply.author.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(reply.timeAgo)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                
                Text(reply.text)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Comment Composer Sheet
struct CommentComposerSheet: View {
    let video: Video
    let replyingTo: RealTimeComment?
    let onSubmit: (RealTimeComment) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @State private var isPosting = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Video info
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 60, height: 34)
                    .cornerRadius(4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(video.title)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(2)
                        
                        Text(video.creator.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Reply indicator
                if let replyingTo = replyingTo {
                    HStack {
                        Text("Replying to @\(replyingTo.author.username)")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Spacer()
                        
                        Button("Cancel Reply") {
                            // Handle cancel reply
                        }
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.primary)
                    }
                    .padding(.horizontal)
                }
                
                // Comment input
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: AppState.shared.currentUser?.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(AppTheme.Colors.primary)
                                .overlay(
                                    Text(String(AppState.shared.currentUser?.displayName.prefix(1) ?? "?"))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppState.shared.currentUser?.displayName ?? "You")
                                .font(.system(size: 14, weight: .medium))
                            
                            TextField(replyingTo != nil ? "Add a reply..." : "Add a comment...", text: $commentText, axis: .vertical)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 14))
                                .lineLimit(5...10)
                                .focused($isTextFieldFocused)
                        }
                    }
                    
                    Rectangle()
                        .fill(AppTheme.Colors.divider)
                        .frame(height: 1)
                        .padding(.leading, 44)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle(replyingTo != nil ? "Reply" : "Add Comment")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: postButton
            )
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private var postButton: some View {
        Button(action: postComment) {
            if isPosting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            } else {
                Text(replyingTo != nil ? "Reply" : "Comment")
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(commentText.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.primary)
        .cornerRadius(16)
        .disabled(commentText.isEmpty || isPosting)
    }
    
    private func postComment() {
        guard !commentText.isEmpty else { return }
        isPosting = true
        if let uid = AppState.shared.currentUser?.id {
            Task {
                try? await CommentsFirestoreService.shared.post(videoId: video.id, userId: uid, text: commentText, parentId: replyingTo?.id)
                await MainActor.run {
                    isPosting = false
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Real Time Comments Manager
@MainActor
class RealTimeCommentsManager: ObservableObject {
    @Published var comments: [RealTimeComment] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var pinnedCommentId: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var videoId: String?
    private var listenerHandle: Any?
    
    func startListening(to videoId: String) {
        self.videoId = videoId
        isLoading = true
        listenerHandle = CommentsFirestoreService.shared.listen(videoId: videoId) { [weak self] items in
            Task { @MainActor in
                self?.comments = items
                self?.isLoading = false
            }
        }
    }
    
    func stopListening() {
        cancellables.removeAll()
        CommentsFirestoreService.shared.stop(listener: listenerHandle)
        listenerHandle = nil
    }
    
    func loadComments() { }
    
    func refreshComments(for videoId: String) async {
        self.videoId = videoId
        await MainActor.run {
            loadComments()
        }
    }
    
    func addComment(_ comment: RealTimeComment) {
        comments.insert(comment, at: 0)
    }
    
    func toggleLike(commentId: String) {
        guard let vId = videoId, let uid = AppState.shared.currentUser?.id else { return }
        let add = true // optimistic toggle; backend will enforce uniqueness
        Task { await CommentsFirestoreService.shared.toggleLike(videoId: vId, commentId: commentId, userId: uid, add: add) }
    }
    
    func reportComment(commentId: String) {
        guard let reporterId = AppState.shared.currentUser?.id else { return }
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let comment = comments.first(where: { $0.id == commentId })
        let reportData: [String: Any] = [
            "type": "comment",
            "contentId": commentId,
            "videoId": videoId ?? "",
            "contentCreatorId": comment?.author.id ?? "",
            "reporterId": reporterId,
            "reason": "user_reported",
            "status": "pending",
            "reviewed": false,
            "createdAt": FieldValue.serverTimestamp()
        ]
        Task {
            try? await db.collection("content_reports").addDocument(data: reportData)
        }
        #endif
        NotificationManager.shared.showSuccess("Comment reported. Thank you for keeping MyChannel safe.")
    }
    
    func pin(commentId: String) {
        pinnedCommentId = commentId
        // Bring pinned to top visually
        if let idx = comments.firstIndex(where: { $0.id == commentId }) {
            let pinned = comments.remove(at: idx)
            comments.insert(pinned, at: 0)
        }
    }
    
    func unpin() {
        pinnedCommentId = nil
    }
    
    private func simulateNewComment() {
        let randomComment = RealTimeComment(
            author: User.sampleUsers.randomElement()!,
            text: ["Amazing video! 🔥", "Love this content!", "First!", "Great explanation!", "Thanks for sharing!"].randomElement()!,
            likeCount: Int.random(in: 0...50),
            replyCount: 0,
            createdAt: Date(),
            isLive: true
        )
        
        comments.insert(randomComment, at: 0)
    }
}

// MARK: - Real Time Comment Model
struct RealTimeComment: Identifiable, Codable {
    let id: String
    let author: User
    let text: String
    var likeCount: Int
    let replyCount: Int
    let createdAt: Date
    let parentId: String?
    let isEdited: Bool
    let isLive: Bool
    let replies: [CommentReply]
    
    init(
        id: String = UUID().uuidString,
        author: User,
        text: String,
        likeCount: Int = 0,
        replyCount: Int = 0,
        createdAt: Date = Date(),
        parentId: String? = nil,
        isEdited: Bool = false,
        isLive: Bool = false,
        replies: [CommentReply] = []
    ) {
        self.id = id
        self.author = author
        self.text = text
        self.likeCount = likeCount
        self.replyCount = replyCount
        self.createdAt = createdAt
        self.parentId = parentId
        self.isEdited = isEdited
        self.isLive = isLive
        self.replies = replies
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

struct CommentReply: Identifiable, Codable {
    let id: String
    let author: User
    let text: String
    let createdAt: Date
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

extension RealTimeComment {
    static let sampleComments: [RealTimeComment] = [
        RealTimeComment(
            author: User.sampleUsers[1],
            text: "This is absolutely incredible! @techcreator you've outdone yourself with this tutorial. The way you explained the concepts was so clear and easy to follow. #SwiftUI #Tutorial",
            likeCount: 156,
            replyCount: 12,
            createdAt: Calendar.current.date(byAdding: .minute, value: -30, to: Date()) ?? Date(),
            replies: [
                CommentReply(
                    id: UUID().uuidString,
                    author: User.sampleUsers[0],
                    text: "Thank you so much! Really appreciate the feedback 🙏",
                    createdAt: Calendar.current.date(byAdding: .minute, value: -25, to: Date()) ?? Date()
                )
            ]
        ),
        RealTimeComment(
            author: User.sampleUsers[2],
            text: "Finally someone who actually knows what they're talking about! Subscribed immediately 🔥 Can't wait for the next video in this series!",
            likeCount: 89,
            replyCount: 5,
            createdAt: Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date(),
            isLive: true
        ),
        RealTimeComment(
            author: User.sampleUsers[3],
            text: "Could you make a follow-up covering advanced animation techniques? This foundation is perfect but I'd love to see more complex examples #AdvancedSwiftUI",
            likeCount: 34,
            replyCount: 3,
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
        )
    ]
}

#Preview {
    RealTimeCommentsView(video: Video.sampleVideos[0])
}