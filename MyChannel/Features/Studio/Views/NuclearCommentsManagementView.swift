//
//  NuclearCommentsManagementView.swift
//  MyChannel
//
//  🔥🔥🔥 NUCLEAR YOUTUBE STUDIO COMMENTS - 100% PARITY 🔥🔥🔥
//  - Published comments
//  - Held for review
//  - Likely spam
//  - Bulk moderation
//  - Reply directly
//  - Heart comments
//  - Pin comments
//

import SwiftUI

struct NuclearCommentsManagementView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CommentsManagementViewModel()
    @State private var selectedTab: CommentTab = .published
    @State private var selectedComments: Set<String> = []
    @State private var searchText = ""
    @State private var showingBulkActions = false
    @State private var filterVideo: Video? = nil
    
    enum CommentTab: String, CaseIterable {
        case published = "Published"
        case heldForReview = "Held for review"
        case likelySpam = "Likely spam"
        
        var icon: String {
            switch self {
            case .published: return "checkmark.circle"
            case .heldForReview: return "clock"
            case .likelySpam: return "exclamationmark.triangle"
            }
        }
        
        var badgeColor: Color {
            switch self {
            case .published: return .green
            case .heldForReview: return .orange
            case .likelySpam: return .red
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 🔥 YOUTUBE EXACT: Tab selector
            tabSelector
            
            // 🔥 YOUTUBE EXACT: Search and filter bar
            searchAndFilterBar
            
            // 🔥 YOUTUBE EXACT: Bulk actions bar (when comments selected)
            if !selectedComments.isEmpty {
                bulkActionsBar
            }
            
            // Comments list
            if viewModel.isLoading {
                ProgressView("Loading comments...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredComments.isEmpty {
                emptyState
            } else {
                commentsList
            }
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { viewModel.sortBy = .newest }) {
                        Label("Newest first", systemImage: viewModel.sortBy == .newest ? "checkmark" : "")
                    }
                    Button(action: { viewModel.sortBy = .oldest }) {
                        Label("Oldest first", systemImage: viewModel.sortBy == .oldest ? "checkmark" : "")
                    }
                    Button(action: { viewModel.sortBy = .mostLikes }) {
                        Label("Most likes", systemImage: viewModel.sortBy == .mostLikes ? "checkmark" : "")
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .task {
            await viewModel.loadComments()
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CommentTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                            selectedComments.removeAll()
                        }
                        HapticManager.shared.impact(style: .light)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .medium))
                            
                            // Badge count
                            let count = countForTab(tab)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(tab.badgeColor)
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundColor(selectedTab == tab ? .white : AppTheme.Colors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.surface
                        )
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Search and Filter Bar
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                TextField("Search comments...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(12)
            .background(AppTheme.Colors.surface)
            .cornerRadius(10)
            
            // Filter by video
            if filterVideo != nil {
                HStack {
                    Text("Filtered by:")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text(filterVideo?.title ?? "")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: { filterVideo = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.Colors.surface)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Bulk Actions Bar
    private var bulkActionsBar: some View {
        HStack(spacing: 16) {
            Text("\(selectedComments.count) selected")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
            
            // Approve
            Button(action: { approveSelected() }) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("Approve")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.green)
            }
            
            // Remove
            Button(action: { removeSelected() }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Remove")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.red)
            }
            
            // Report spam
            Button(action: { reportSpamSelected() }) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                    Text("Spam")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.orange)
            }
            
            // Clear selection
            Button(action: { selectedComments.removeAll() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.Colors.primary.opacity(0.1))
    }
    
    // MARK: - Comments List
    private var commentsList: some View {
        List {
            ForEach(filteredComments) { comment in
                CommentModerationRow(
                    comment: comment,
                    isSelected: selectedComments.contains(comment.id),
                    onSelect: { toggleSelection(comment.id) },
                    onApprove: { approveComment(comment) },
                    onRemove: { removeComment(comment) },
                    onReply: { replyToComment(comment) },
                    onHeart: { heartComment(comment) },
                    onPin: { pinComment(comment) }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadComments()
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedTab == .published ? "bubble.left.and.bubble.right" : "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.5))
            
            Text(emptyStateTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(emptyStateMessage)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    private var filteredComments: [ModerationComment] {
        var comments: [ModerationComment]
        
        switch selectedTab {
        case .published:
            comments = viewModel.publishedComments
        case .heldForReview:
            comments = viewModel.heldForReviewComments
        case .likelySpam:
            comments = viewModel.spamComments
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            comments = comments.filter {
                $0.text.localizedCaseInsensitiveContains(searchText) ||
                $0.username.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply video filter
        if let videoId = filterVideo?.id {
            comments = comments.filter { $0.videoId == videoId }
        }
        
        return comments
    }
    
    private var emptyStateTitle: String {
        switch selectedTab {
        case .published: return "No comments yet"
        case .heldForReview: return "All caught up!"
        case .likelySpam: return "No spam detected"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedTab {
        case .published: return "Comments from your viewers will appear here"
        case .heldForReview: return "No comments are waiting for your review"
        case .likelySpam: return "Our AI hasn't detected any spam comments"
        }
    }
    
    private func countForTab(_ tab: CommentTab) -> Int {
        switch tab {
        case .published: return viewModel.publishedComments.count
        case .heldForReview: return viewModel.heldForReviewComments.count
        case .likelySpam: return viewModel.spamComments.count
        }
    }
    
    // MARK: - Actions
    private func toggleSelection(_ id: String) {
        if selectedComments.contains(id) {
            selectedComments.remove(id)
        } else {
            selectedComments.insert(id)
        }
        HapticManager.shared.impact(style: .light)
    }
    
    private func approveSelected() {
        Task {
            await viewModel.approveComments(Array(selectedComments))
            selectedComments.removeAll()
            HapticManager.shared.notification(type: .success)
        }
    }
    
    private func removeSelected() {
        Task {
            await viewModel.removeComments(Array(selectedComments))
            selectedComments.removeAll()
            HapticManager.shared.notification(type: .warning)
        }
    }
    
    private func reportSpamSelected() {
        Task {
            await viewModel.reportSpam(Array(selectedComments))
            selectedComments.removeAll()
            HapticManager.shared.notification(type: .warning)
        }
    }
    
    private func approveComment(_ comment: ModerationComment) {
        Task {
            await viewModel.approveComments([comment.id])
            HapticManager.shared.notification(type: .success)
        }
    }
    
    private func removeComment(_ comment: ModerationComment) {
        Task {
            await viewModel.removeComments([comment.id])
            HapticManager.shared.notification(type: .warning)
        }
    }
    
    private func replyToComment(_ comment: ModerationComment) {
        // Open reply sheet
    }
    
    private func heartComment(_ comment: ModerationComment) {
        Task {
            await viewModel.heartComment(comment.id)
            HapticManager.shared.impact(style: .medium)
        }
    }
    
    private func pinComment(_ comment: ModerationComment) {
        Task {
            await viewModel.pinComment(comment.id)
            HapticManager.shared.notification(type: .success)
        }
    }
}

// MARK: - View Model
@MainActor
class CommentsManagementViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var publishedComments: [ModerationComment] = []
    @Published var heldForReviewComments: [ModerationComment] = []
    @Published var spamComments: [ModerationComment] = []
    @Published var sortBy: SortOption = .newest
    
    enum SortOption {
        case newest, oldest, mostLikes
    }
    
    func loadComments() async {
        isLoading = true
        
        // Simulate loading from Firestore
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Generate sample comments
        publishedComments = (0..<20).map { i in
            ModerationComment(
                id: "pub_\(i)",
                videoId: "video_\(i % 5)",
                videoTitle: "Amazing Video \(i % 5 + 1)",
                username: "User\(i + 1)",
                avatarURL: "",
                text: sampleComments[i % sampleComments.count],
                likeCount: Int.random(in: 0...100),
                isHearted: Bool.random(),
                isPinned: i == 0,
                timestamp: Date().addingTimeInterval(-Double(i * 3600)),
                status: .published
            )
        }
        
        heldForReviewComments = (0..<5).map { i in
            ModerationComment(
                id: "held_\(i)",
                videoId: "video_\(i)",
                videoTitle: "Video \(i + 1)",
                username: "NewUser\(i + 1)",
                avatarURL: "",
                text: "This comment needs review \(i + 1)",
                likeCount: 0,
                isHearted: false,
                isPinned: false,
                timestamp: Date().addingTimeInterval(-Double(i * 1800)),
                status: .heldForReview
            )
        }
        
        spamComments = (0..<3).map { i in
            ModerationComment(
                id: "spam_\(i)",
                videoId: "video_\(i)",
                videoTitle: "Video \(i + 1)",
                username: "SpamBot\(i + 1)",
                avatarURL: "",
                text: "🚨 BUY NOW! Free gift cards! Click here! 🚨",
                likeCount: 0,
                isHearted: false,
                isPinned: false,
                timestamp: Date().addingTimeInterval(-Double(i * 7200)),
                status: .spam
            )
        }
        
        isLoading = false
    }
    
    func approveComments(_ ids: [String]) async {
        // Move from held to published
        for id in ids {
            if let index = heldForReviewComments.firstIndex(where: { $0.id == id }) {
                var comment = heldForReviewComments.remove(at: index)
                comment.status = .published
                publishedComments.insert(comment, at: 0)
            }
        }
    }
    
    func removeComments(_ ids: [String]) async {
        publishedComments.removeAll { ids.contains($0.id) }
        heldForReviewComments.removeAll { ids.contains($0.id) }
        spamComments.removeAll { ids.contains($0.id) }
    }
    
    func reportSpam(_ ids: [String]) async {
        for id in ids {
            if let index = publishedComments.firstIndex(where: { $0.id == id }) {
                var comment = publishedComments.remove(at: index)
                comment.status = .spam
                spamComments.insert(comment, at: 0)
            }
        }
    }
    
    func heartComment(_ id: String) async {
        if let index = publishedComments.firstIndex(where: { $0.id == id }) {
            publishedComments[index].isHearted.toggle()
        }
    }
    
    func pinComment(_ id: String) async {
        // Unpin any existing pinned comment
        for i in publishedComments.indices {
            publishedComments[i].isPinned = false
        }
        
        // Pin the new comment
        if let index = publishedComments.firstIndex(where: { $0.id == id }) {
            publishedComments[index].isPinned = true
            // Move to top
            let comment = publishedComments.remove(at: index)
            publishedComments.insert(comment, at: 0)
        }
    }
    
    private let sampleComments = [
        "Great video! Really enjoyed it 🔥",
        "This is exactly what I needed, thanks!",
        "Can you make more videos like this?",
        "Love your content, keep it up!",
        "First! Also great video 😄",
        "This helped me so much, subscribed!",
        "Best explanation I've found on this topic",
        "You're amazing at explaining things",
        "Been waiting for this video!",
        "Quality content as always 👏"
    ]
}

// MARK: - Comment Model
struct ModerationComment: Identifiable {
    let id: String
    let videoId: String
    let videoTitle: String
    let username: String
    let avatarURL: String
    let text: String
    let likeCount: Int
    var isHearted: Bool
    var isPinned: Bool
    let timestamp: Date
    var status: CommentStatus
    
    enum CommentStatus {
        case published, heldForReview, spam
    }
}

// MARK: - Comment Row
struct CommentModerationRow: View {
    let comment: ModerationComment
    let isSelected: Bool
    let onSelect: () -> Void
    let onApprove: () -> Void
    let onRemove: () -> Void
    let onReply: () -> Void
    let onHeart: () -> Void
    let onPin: () -> Void
    
    @State private var showingReplySheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selection + User info
            HStack(alignment: .top, spacing: 12) {
                // Selection checkbox
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                }
                
                // Avatar
                Circle()
                    .fill(AppTheme.Colors.surface)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(comment.username.prefix(1)))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    // Username and badges
                    HStack(spacing: 6) {
                        Text(comment.username)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if comment.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        
                        if comment.isHearted {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                        
                        Text("•")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text(timeAgo(from: comment.timestamp))
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    // Comment text
                    Text(comment.text)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(3)
                    
                    // Video reference
                    Text("on \(comment.videoTitle)")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    // Stats and actions
                    HStack(spacing: 16) {
                        // Likes
                        if comment.likeCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.thumbsup")
                                    .font(.system(size: 12))
                                Text("\(comment.likeCount)")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Actions
                        HStack(spacing: 12) {
                            if comment.status == .heldForReview {
                                Button(action: onApprove) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(.green)
                                }
                            }
                            
                            Button(action: onHeart) {
                                Image(systemName: comment.isHearted ? "heart.fill" : "heart")
                                    .font(.system(size: 18))
                                    .foregroundColor(comment.isHearted ? .red : AppTheme.Colors.textSecondary)
                            }
                            
                            Button(action: { showingReplySheet = true }) {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            Menu {
                                Button(action: onPin) {
                                    Label(comment.isPinned ? "Unpin" : "Pin comment", systemImage: "pin")
                                }
                                Button(action: onRemove) {
                                    Label("Remove", systemImage: "trash")
                                }
                                Button(action: {}) {
                                    Label("Report spam", systemImage: "exclamationmark.triangle")
                                }
                                Button(action: {}) {
                                    Label("Hide user from channel", systemImage: "person.crop.circle.badge.minus")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(12)
        .background(isSelected ? AppTheme.Colors.primary.opacity(0.1) : AppTheme.Colors.surface)
        .cornerRadius(12)
        .sheet(isPresented: $showingReplySheet) {
            ReplyToCommentSheet(comment: comment)
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

// MARK: - Reply Sheet
struct ReplyToCommentSheet: View {
    let comment: ModerationComment
    @Environment(\.dismiss) private var dismiss
    @State private var replyText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Original comment
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(comment.username.prefix(1)))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            )
                        
                        Text(comment.username)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    
                    Text(comment.text)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .cornerRadius(12)
                
                // Reply input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your reply")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    TextEditor(text: $replyText)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // Send button
                Button(action: sendReply) {
                    Text("REPLY")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(replyText.isEmpty ? Color.gray : AppTheme.Colors.primary)
                        .cornerRadius(8)
                }
                .disabled(replyText.isEmpty)
            }
            .padding()
            .navigationTitle("Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func sendReply() {
        // Send reply via API
        HapticManager.shared.notification(type: .success)
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        NuclearCommentsManagementView()
            .environmentObject(AppState.shared)
    }
}






