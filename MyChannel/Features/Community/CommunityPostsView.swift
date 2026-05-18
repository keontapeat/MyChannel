import SwiftUI

struct CommunityPostsView: View {
    let creatorId: String
    @StateObject private var postService = CommunityPostService.shared
    @EnvironmentObject private var appState: AppState
    @State private var showingCreatePost = false
    
    var body: some View {
        List {
            ForEach(postService.posts) { post in
                CommunityPostRow(post: post) { postId in
                    if let uid = appState.currentUser?.id {
                        Task { await postService.toggleLike(postId: postId, userId: uid, add: true) }
                    }
                } onVote: { postId, optionIndex in
                    if let uid = appState.currentUser?.id {
                        Task { await postService.votePoll(postId: postId, userId: uid, optionIndex: optionIndex) }
                    }
                }
                .onAppear {
                    addPostToHistory(post)
                }
            }
        }
        .listStyle(.plain)
        .onAppear {
            postService.listenToPosts(creatorId: creatorId)
        }
        .onDisappear {
            postService.stopListening()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreatePost = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreatePost) {
            if let creator = appState.currentUser {
                CreateCommunityPostView(creator: creator)
            }
        }
    }
    
    private func addPostToHistory(_ post: CommunityPost) {
        guard let userId = appState.currentUser?.id else { return }
        let creator = appState.currentUser ?? User(id: creatorId, username: "creator", displayName: "Creator", email: "")
        Task {
            let item = WatchHistoryItem.fromCommunityPost(post, creator: creator)
            await HistoryService.shared.addOrUpdateHistoryItem(item, userId: userId)
        }
    }
}

struct CommunityPostRow: View {
    let post: CommunityPost
    let onLike: (String) -> Void
    let onVote: (String, Int) -> Void
    
    private func pollPercentageText(votes: Int, total: Int) -> String {
        let percentage = Int(Double(votes) / Double(total) * 100)
        return "\(percentage)%"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Post content
            Text(post.content)
                .font(.body)
            
            // Images if present
            if !post.imageURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.imageURLs, id: \.self) { imageURL in
                            AsyncImage(url: URL(string: imageURL)) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Rectangle().fill(Color(.systemGray6)).frame(height: 200)
                            }
                            .frame(maxWidth: 300, maxHeight: 200)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Poll if present
            if let poll = post.poll {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(poll.options.enumerated()), id: \.offset) { index, option in
                        Button {
                            onVote(post.id, index)
                        } label: {
                            HStack {
                                Text(option.text)
                                    .font(.subheadline)
                                Spacer()
                                if poll.totalVotes > 0 {
                                    Text(pollPercentageText(votes: option.voteCount, total: poll.totalVotes))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("\(poll.totalVotes) votes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Actions
            HStack {
                Button {
                    onLike(post.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .foregroundColor(.secondary)
                        Text("\(post.likeCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(.secondary)
                    Text("\(post.commentCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(post.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// CreateCommunityPostView is in a separate file
