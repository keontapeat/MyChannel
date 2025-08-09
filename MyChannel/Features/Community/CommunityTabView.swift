//
//  CommunityTabView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct CommunityTabView: View {
    let creator: User
    @StateObject private var communityService = MockCommunityService()
    @State private var posts: [CommunityPost] = []
    @State private var isLoading = false
    @State private var showingCreatePost = false
    @State private var selectedPostType: PostType = .text
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Create Post Section (if owner)
                    if isCreatorView {
                        createPostSection
                    }
                    
                    // Posts Feed
                    if isLoading && posts.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in
                            CommunityPostPlaceholder()
                        }
                    } else if posts.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(posts) { post in
                            CommunityPostCard(
                                post: post,
                                creator: creator,
                                communityService: communityService,
                                onLike: { likePost(post) },
                                onComment: { showComments(post) },
                                onShare: { sharePost(post) },
                                onDelete: { deletePost(post) }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if isCreatorView {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingCreatePost = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
            }
            .refreshable {
                await loadPosts()
            }
            .sheet(isPresented: $showingCreatePost) {
                CommunityCreatePostWrapper(creator: creator, communityService: communityService)
            }
        }
        .task {
            await loadPosts()
        }
    }
    
    private var isCreatorView: Bool {
        // In a real app, check if current user is the creator
        true
    }
    
    private var createPostSection: some View {
        VStack(spacing: 12) {
            HStack {
                AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(.secondary)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                Button(action: { showingCreatePost = true }) {
                    HStack {
                        Text("Share something with your community...")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 16) {
                ForEach([PostType.text, PostType.image, PostType.video, PostType.poll], id: \.self) { type in
                    Button(action: {
                        selectedPostType = type
                        showingCreatePost = true
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: type.iconName)
                                .font(.title3)
                                .foregroundColor(type.color)
                            Text(type.displayName.components(separatedBy: " ").first ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Community Posts Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start engaging with your audience by sharing updates, polls, and behind-the-scenes content")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if isCreatorView {
                Button("Create Your First Post") {
                    showingCreatePost = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 60)
    }
    
    // MARK: - Actions
    private func loadPosts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let loadedPosts = try await communityService.getCommunityPosts(for: creator.id, limit: 20)
            await MainActor.run {
                self.posts = loadedPosts
            }
        } catch {
            print("Error loading posts: \(error)")
        }
    }
    
    private func likePost(_ post: CommunityPost) {
        Task {
            do {
                try await communityService.likePost(id: post.id, userId: "current-user-id")
                await loadPosts()
            } catch {
                print("Error liking post: \(error)")
            }
        }
    }
    
    private func sharePost(_ post: CommunityPost) {
        Task {
            do {
                try await communityService.sharePost(id: post.id, userId: "current-user-id")
                await loadPosts()
            } catch {
                print("Error sharing post: \(error)")
            }
        }
    }
    
    private func deletePost(_ post: CommunityPost) {
        Task {
            do {
                try await communityService.deletePost(id: post.id)
                await loadPosts()
            } catch {
                print("Error deleting post: \(error)")
            }
        }
    }
    
    private func showComments(_ post: CommunityPost) {
        // TODO: Navigate to comments view
        print("Show comments for post: \(post.id)")
    }
}

// MARK: - Community Post Card
struct CommunityPostCard: View {
    let post: CommunityPost
    let creator: User
    @ObservedObject var communityService: MockCommunityService
    let onLike: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    
    @State private var showingActionSheet = false
    @State private var selectedPollOption: PollOption?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            postHeader
            
            // Content
            postContent
            
            // Media
            if !post.imageURLs.isEmpty {
                postImages
            }
            
            if let videoURL = post.videoURL {
                postVideo(videoURL)
            }
            
            // Poll
            if let poll = post.poll {
                pollView(poll)
            }
            
            // Engagement Bar
            engagementBar
            
            // Action Buttons
            actionButtons
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .confirmationDialog("Post Options", isPresented: $showingActionSheet) {
            Button("Share", action: onShare)
            Button("Pin Post") { pinPost() }
            Button("Edit Post") { editPost() }
            Button("Delete Post", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private var postHeader: some View {
        HStack {
            AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray5))
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(creator.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                    
                    if post.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                
                HStack {
                    Text(post.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if post.isEdited {
                        Text("• edited")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: post.postType.iconName)
                        Text(post.postType.displayName)
                    }
                    .font(.caption)
                    .foregroundColor(post.postType.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(post.postType.color.opacity(0.1))
                    .cornerRadius(4)
                }
            }
            
            Spacer()
            
            Button(action: { showingActionSheet = true }) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var postContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            
            if !post.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.horizontal, -16)
            }
        }
    }
    
    private var postImages: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(post.imageURLs, id: \.self) { imageURL in
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                    }
                    .frame(width: 200, height: 200)
                    .cornerRadius(12)
                    .clipped()
                }
            }
            .padding(.horizontal)
        }
        .padding(.horizontal, -16)
    }
    
    private func postVideo(_ videoURL: String) -> some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(height: 200)
            .cornerRadius(12)
            .overlay(
                VStack {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    Text("Community Video")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            )
    }
    
    private func pollView(_ poll: Poll) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(poll.question)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(poll.options) { option in
                    Button(action: {
                        if poll.isActive {
                            votePoll(poll: poll, option: option)
                        }
                    }) {
                        HStack {
                            Text(option.text)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if poll.totalVotes > 0 {
                                Text("\(Int(option.percentage(of: poll.totalVotes)))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("\(option.voteCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                                
                                if poll.totalVotes > 0 {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.3))
                                        .frame(width: CGFloat(option.percentage(of: poll.totalVotes) / 100) * 300)
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(option.hasVoted ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!poll.isActive)
                }
            }
            
            HStack {
                Text("\(poll.totalVotes) votes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let timeRemaining = poll.timeRemaining {
                    Text("• \(timeRemaining) left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if !poll.isActive {
                    Text("• Poll ended")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var engagementBar: some View {
        HStack {
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("\(post.likeCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("\(post.commentCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("\(post.shareCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
        }
        .foregroundColor(.secondary)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 0) {
            Button(action: onLike) {
                HStack(spacing: 6) {
                    Image(systemName: "heart")
                        .font(.subheadline)
                    Text("Like")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            
            Button(action: onComment) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .font(.subheadline)
                    Text("Comment")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            
            Button(action: onShare) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                    Text("Share")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Actions
    private func votePoll(poll: Poll, option: PollOption) {
        Task {
            do {
                _ = try await communityService.votePoll(pollId: poll.id, optionId: option.id, userId: "current-user-id")
            } catch {
                print("Error voting on poll: \(error)")
            }
        }
    }
    
    private func pinPost() {
        Task {
            do {
                if post.isPinned {
                    try await communityService.unpinPost(id: post.id)
                } else {
                    try await communityService.pinPost(id: post.id)
                }
            } catch {
                print("Error pinning post: \(error)")
            }
        }
    }
    
    private func editPost() {
        // TODO: Navigate to edit post view
        print("Edit post: \(post.id)")
    }
}

// MARK: - Supporting Views
struct CommunityPostPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 120, height: 16)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 12)
                }
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 200, height: 16)
                    Spacer()
                }
            }
            
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 12)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 12)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 12)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MOVE: Move wrapper to bottom so CommunityTabView stays first in jump bar
struct CommunityCreatePostWrapper: View {
    let creator: User
    @ObservedObject var communityService: MockCommunityService
    var body: some View {
        CreateCommunityPostView(creator: creator, communityService: communityService)
    }
}

#Preview("Community Create Post Wrapper") {
    CommunityCreatePostWrapper(creator: User.sampleUsers[0], communityService: MockCommunityService())
}

#Preview {
    NavigationStack {
        CommunityTabView(creator: User.sampleUsers[0])
    }
}