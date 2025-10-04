//
//  Community.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

// MARK: - Community Post Model
struct CommunityPost: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let creatorId: String
    let content: String
    let imageURLs: [String]
    let videoURL: String?
    let postType: PostType
    let createdAt: Date
    let updatedAt: Date
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let isPinned: Bool
    let isEdited: Bool
    let poll: Poll?
    let tags: [String]
    
    init(
        id: String = UUID().uuidString,
        creatorId: String,
        content: String,
        imageURLs: [String] = [],
        videoURL: String? = nil,
        postType: PostType = .text,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        likeCount: Int = 0,
        commentCount: Int = 0,
        shareCount: Int = 0,
        isPinned: Bool = false,
        isEdited: Bool = false,
        poll: Poll? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.creatorId = creatorId
        self.content = content
        self.imageURLs = imageURLs
        self.videoURL = videoURL
        self.postType = postType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.shareCount = shareCount
        self.isPinned = isPinned
        self.isEdited = isEdited
        self.poll = poll
        self.tags = tags
    }
    
    // MARK: - Equatable & Hashable
    static func == (lhs: CommunityPost, rhs: CommunityPost) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Post Type Enum
enum PostType: String, CaseIterable, Codable {
    case text = "text"
    case image = "image"
    case video = "video"
    case poll = "poll"
    case announcement = "announcement"
    case milestone = "milestone"
    case live = "live"
    
    var displayName: String {
        switch self {
        case .text: return "Text Post"
        case .image: return "Image Post"
        case .video: return "Video Post"
        case .poll: return "Poll"
        case .announcement: return "Announcement"
        case .milestone: return "Milestone"
        case .live: return "Live Update"
        }
    }
    
    var iconName: String {
        switch self {
        case .text: return "text.bubble"
        case .image: return "photo"
        case .video: return "video"
        case .poll: return "chart.bar"
        case .announcement: return "megaphone"
        case .milestone: return "trophy"
        case .live: return "dot.radiowaves.left.and.right"
        }
    }
    
    var color: Color {
        switch self {
        case .text: return .primary
        case .image: return .green
        case .video: return .blue
        case .poll: return .orange
        case .announcement: return .red
        case .milestone: return .yellow
        case .live: return .pink
        }
    }
}

// MARK: - Poll Model
struct Poll: Identifiable, Codable, Equatable {
    let id: String
    let question: String
    let options: [PollOption]
    let endsAt: Date?
    let allowMultipleChoices: Bool
    let totalVotes: Int
    
    init(
        id: String = UUID().uuidString,
        question: String,
        options: [PollOption],
        endsAt: Date? = nil,
        allowMultipleChoices: Bool = false
    ) {
        self.id = id
        self.question = question
        self.options = options
        self.endsAt = endsAt
        self.allowMultipleChoices = allowMultipleChoices
        self.totalVotes = options.reduce(0) { $0 + $1.voteCount }
    }
    
    var isActive: Bool {
        guard let endsAt = endsAt else { return true }
        return Date() < endsAt
    }
    
    var timeRemaining: String? {
        guard let endsAt = endsAt, isActive else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: endsAt, relativeTo: Date())
    }
    
    // MARK: - Equatable
    static func == (lhs: Poll, rhs: Poll) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Poll Option Model
struct PollOption: Identifiable, Codable, Equatable {
    let id: String
    let text: String
    let voteCount: Int
    let hasVoted: Bool
    
    init(
        id: String = UUID().uuidString,
        text: String,
        voteCount: Int = 0,
        hasVoted: Bool = false
    ) {
        self.id = id
        self.text = text
        self.voteCount = voteCount
        self.hasVoted = hasVoted
    }
    
    func percentage(of total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(voteCount) / Double(total) * 100
    }
    
    // MARK: - Equatable
    static func == (lhs: PollOption, rhs: PollOption) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Community Comment Model
struct CommunityComment: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let postId: String
    let userId: String
    let content: String
    let createdAt: Date
    let likeCount: Int
    let replyCount: Int
    let parentCommentId: String?
    let isCreatorHeart: Bool
    let isPinned: Bool
    
    init(
        id: String = UUID().uuidString,
        postId: String,
        userId: String,
        content: String,
        createdAt: Date = Date(),
        likeCount: Int = 0,
        replyCount: Int = 0,
        parentCommentId: String? = nil,
        isCreatorHeart: Bool = false,
        isPinned: Bool = false
    ) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.content = content
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.replyCount = replyCount
        self.parentCommentId = parentCommentId
        self.isCreatorHeart = isCreatorHeart
        self.isPinned = isPinned
    }
    
    var isReply: Bool {
        parentCommentId != nil
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    // MARK: - Equatable & Hashable
    static func == (lhs: CommunityComment, rhs: CommunityComment) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Community Service Protocol
protocol CommunityServiceProtocol {
    func getCommunityPosts(for creatorId: String, limit: Int) async throws -> [CommunityPost]
    func createPost(_ post: CommunityPost) async throws -> CommunityPost
    func updatePost(_ post: CommunityPost) async throws -> CommunityPost
    func deletePost(id: String) async throws
    func likePost(id: String, userId: String) async throws
    func unlikePost(id: String, userId: String) async throws
    func sharePost(id: String, userId: String) async throws
    func pinPost(id: String) async throws
    func unpinPost(id: String) async throws
    
    // Comments
    func getComments(for postId: String) async throws -> [CommunityComment]
    func createComment(_ comment: CommunityComment) async throws -> CommunityComment
    func likeComment(id: String, userId: String) async throws
    func heartComment(id: String, creatorId: String) async throws
    
    // Polls
    func votePoll(pollId: String, optionId: String, userId: String) async throws -> Poll
}

// MARK: - Mock Community Service
class MockCommunityService: CommunityServiceProtocol, ObservableObject {
    @Published var posts: [CommunityPost] = CommunityPost.samplePosts
    @Published var comments: [CommunityComment] = CommunityComment.sampleComments
    @Published var isLoading = false
    
    func getCommunityPosts(for creatorId: String, limit: Int) async throws -> [CommunityPost] {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        return posts
            .filter { $0.creatorId == creatorId }
            .sorted { post1, post2 in
                if post1.isPinned && !post2.isPinned {
                    return true
                } else if !post1.isPinned && post2.isPinned {
                    return false
                } else {
                    return post1.createdAt > post2.createdAt
                }
            }
            .prefix(limit)
            .map { $0 }
    }
    
    func createPost(_ post: CommunityPost) async throws -> CommunityPost {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            posts.append(post)
        }
        
        return post
    }
    
    func updatePost(_ post: CommunityPost) async throws -> CommunityPost {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else {
            throw NSError(domain: "CommunityError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"])
        }
        
        let updatedPost = CommunityPost(
            id: post.id,
            creatorId: post.creatorId,
            content: post.content,
            imageURLs: post.imageURLs,
            videoURL: post.videoURL,
            postType: post.postType,
            createdAt: post.createdAt,
            updatedAt: Date(),
            likeCount: post.likeCount,
            commentCount: post.commentCount,
            shareCount: post.shareCount,
            isPinned: post.isPinned,
            isEdited: true,
            poll: post.poll,
            tags: post.tags
        )
        
        await MainActor.run {
            posts[index] = updatedPost
        }
        
        return updatedPost
    }
    
    func deletePost(id: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        await MainActor.run {
            posts.removeAll { $0.id == id }
            comments.removeAll { $0.postId == id }
        }
    }
    
    func likePost(id: String, userId: String) async throws {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
        
        let updatedPost = CommunityPost(
            id: posts[index].id,
            creatorId: posts[index].creatorId,
            content: posts[index].content,
            imageURLs: posts[index].imageURLs,
            videoURL: posts[index].videoURL,
            postType: posts[index].postType,
            createdAt: posts[index].createdAt,
            updatedAt: posts[index].updatedAt,
            likeCount: posts[index].likeCount + 1,
            commentCount: posts[index].commentCount,
            shareCount: posts[index].shareCount,
            isPinned: posts[index].isPinned,
            isEdited: posts[index].isEdited,
            poll: posts[index].poll,
            tags: posts[index].tags
        )
        
        await MainActor.run {
            posts[index] = updatedPost
        }
    }
    
    func unlikePost(id: String, userId: String) async throws {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
        
        let updatedPost = CommunityPost(
            id: posts[index].id,
            creatorId: posts[index].creatorId,
            content: posts[index].content,
            imageURLs: posts[index].imageURLs,
            videoURL: posts[index].videoURL,
            postType: posts[index].postType,
            createdAt: posts[index].createdAt,
            updatedAt: posts[index].updatedAt,
            likeCount: max(0, posts[index].likeCount - 1),
            commentCount: posts[index].commentCount,
            shareCount: posts[index].shareCount,
            isPinned: posts[index].isPinned,
            isEdited: posts[index].isEdited,
            poll: posts[index].poll,
            tags: posts[index].tags
        )
        
        await MainActor.run {
            posts[index] = updatedPost
        }
    }
    
    func sharePost(id: String, userId: String) async throws {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
        
        let updatedPost = CommunityPost(
            id: posts[index].id,
            creatorId: posts[index].creatorId,
            content: posts[index].content,
            imageURLs: posts[index].imageURLs,
            videoURL: posts[index].videoURL,
            postType: posts[index].postType,
            createdAt: posts[index].createdAt,
            updatedAt: posts[index].updatedAt,
            likeCount: posts[index].likeCount,
            commentCount: posts[index].commentCount,
            shareCount: posts[index].shareCount + 1,
            isPinned: posts[index].isPinned,
            isEdited: posts[index].isEdited,
            poll: posts[index].poll,
            tags: posts[index].tags
        )
        
        await MainActor.run {
            posts[index] = updatedPost
        }
    }
    
    func pinPost(id: String) async throws {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
        
        // Unpin other posts first
        for i in posts.indices {
            if posts[i].isPinned {
                let unpinnedPost = CommunityPost(
                    id: posts[i].id,
                    creatorId: posts[i].creatorId,
                    content: posts[i].content,
                    imageURLs: posts[i].imageURLs,
                    videoURL: posts[i].videoURL,
                    postType: posts[i].postType,
                    createdAt: posts[i].createdAt,
                    updatedAt: posts[i].updatedAt,
                    likeCount: posts[i].likeCount,
                    commentCount: posts[i].commentCount,
                    shareCount: posts[i].shareCount,
                    isPinned: false,
                    isEdited: posts[i].isEdited,
                    poll: posts[i].poll,
                    tags: posts[i].tags
                )
                posts[i] = unpinnedPost
            }
        }
        
        // Pin the selected post
        let pinnedPost = CommunityPost(
            id: posts[index].id,
            creatorId: posts[index].creatorId,
            content: posts[index].content,
            imageURLs: posts[index].imageURLs,
            videoURL: posts[index].videoURL,
            postType: posts[index].postType,
            createdAt: posts[index].createdAt,
            updatedAt: posts[index].updatedAt,
            likeCount: posts[index].likeCount,
            commentCount: posts[index].commentCount,
            shareCount: posts[index].shareCount,
            isPinned: true,
            isEdited: posts[index].isEdited,
            poll: posts[index].poll,
            tags: posts[index].tags
        )
        
        await MainActor.run {
            posts[index] = pinnedPost
        }
    }
    
    func unpinPost(id: String) async throws {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
        
        let unpinnedPost = CommunityPost(
            id: posts[index].id,
            creatorId: posts[index].creatorId,
            content: posts[index].content,
            imageURLs: posts[index].imageURLs,
            videoURL: posts[index].videoURL,
            postType: posts[index].postType,
            createdAt: posts[index].createdAt,
            updatedAt: posts[index].updatedAt,
            likeCount: posts[index].likeCount,
            commentCount: posts[index].commentCount,
            shareCount: posts[index].shareCount,
            isPinned: false,
            isEdited: posts[index].isEdited,
            poll: posts[index].poll,
            tags: posts[index].tags
        )
        
        await MainActor.run {
            posts[index] = unpinnedPost
        }
    }
    
    // MARK: - Comments
    func getComments(for postId: String) async throws -> [CommunityComment] {
        return comments
            .filter { $0.postId == postId }
            .sorted { comment1, comment2 in
                if comment1.isPinned && !comment2.isPinned {
                    return true
                } else if !comment1.isPinned && comment2.isPinned {
                    return false
                } else {
                    return comment1.createdAt < comment2.createdAt
                }
            }
    }
    
    func createComment(_ comment: CommunityComment) async throws -> CommunityComment {
        await MainActor.run {
            comments.append(comment)
        }
        return comment
    }
    
    func likeComment(id: String, userId: String) async throws {
        guard let index = comments.firstIndex(where: { $0.id == id }) else { return }
        
        let updatedComment = CommunityComment(
            id: comments[index].id,
            postId: comments[index].postId,
            userId: comments[index].userId,
            content: comments[index].content,
            createdAt: comments[index].createdAt,
            likeCount: comments[index].likeCount + 1,
            replyCount: comments[index].replyCount,
            parentCommentId: comments[index].parentCommentId,
            isCreatorHeart: comments[index].isCreatorHeart,
            isPinned: comments[index].isPinned
        )
        
        await MainActor.run {
            comments[index] = updatedComment
        }
    }
    
    func heartComment(id: String, creatorId: String) async throws {
        guard let index = comments.firstIndex(where: { $0.id == id }) else { return }
        
        let updatedComment = CommunityComment(
            id: comments[index].id,
            postId: comments[index].postId,
            userId: comments[index].userId,
            content: comments[index].content,
            createdAt: comments[index].createdAt,
            likeCount: comments[index].likeCount,
            replyCount: comments[index].replyCount,
            parentCommentId: comments[index].parentCommentId,
            isCreatorHeart: !comments[index].isCreatorHeart,
            isPinned: comments[index].isPinned
        )
        
        await MainActor.run {
            comments[index] = updatedComment
        }
    }
    
    // MARK: - Polls
    func votePoll(pollId: String, optionId: String, userId: String) async throws -> Poll {
        guard let postIndex = posts.firstIndex(where: { $0.poll?.id == pollId }),
              let poll = posts[postIndex].poll,
              let optionIndex = poll.options.firstIndex(where: { $0.id == optionId }) else {
            throw NSError(domain: "CommunityError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Poll or option not found"])
        }
        
        var updatedOptions = poll.options
        updatedOptions[optionIndex] = PollOption(
            id: updatedOptions[optionIndex].id,
            text: updatedOptions[optionIndex].text,
            voteCount: updatedOptions[optionIndex].voteCount + 1,
            hasVoted: true
        )
        
        let updatedPoll = Poll(
            id: poll.id,
            question: poll.question,
            options: updatedOptions,
            endsAt: poll.endsAt,
            allowMultipleChoices: poll.allowMultipleChoices
        )
        
        let updatedPost = CommunityPost(
            id: posts[postIndex].id,
            creatorId: posts[postIndex].creatorId,
            content: posts[postIndex].content,
            imageURLs: posts[postIndex].imageURLs,
            videoURL: posts[postIndex].videoURL,
            postType: posts[postIndex].postType,
            createdAt: posts[postIndex].createdAt,
            updatedAt: posts[postIndex].updatedAt,
            likeCount: posts[postIndex].likeCount,
            commentCount: posts[postIndex].commentCount,
            shareCount: posts[postIndex].shareCount,
            isPinned: posts[postIndex].isPinned,
            isEdited: posts[postIndex].isEdited,
            poll: updatedPoll,
            tags: posts[postIndex].tags
        )
        
        await MainActor.run {
            posts[postIndex] = updatedPost
        }
        
        return updatedPoll
    }
}

// MARK: - Sample Data
extension CommunityPost {
    static let samplePosts: [CommunityPost] = [
        CommunityPost(
            creatorId: User.sampleUsers[0].id,
            content: "🚀 Exciting news! I'm working on a brand new SwiftUI tutorial series that will cover everything from basics to advanced animations. What specific topics would you like me to cover? Drop your suggestions below! 👇",
            postType: .announcement,
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
            likeCount: 234,
            commentCount: 45,
            shareCount: 12,
            isPinned: true,
            tags: ["SwiftUI", "iOS", "Tutorial"]
        ),
        CommunityPost(
            creatorId: User.sampleUsers[0].id,
            content: "Check out this amazing sunset I captured during my last trip! 🌅 Sometimes you need to step away from code and appreciate the beauty around us.",
            imageURLs: ["https://picsum.photos/800/600?random=sunset1", "https://picsum.photos/800/600?random=sunset2"],
            postType: .image,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            likeCount: 567,
            commentCount: 89,
            shareCount: 34,
            tags: ["Photography", "Travel", "Nature"]
        ),
        CommunityPost(
            creatorId: User.sampleUsers[1].id,
            content: "What's your favorite digital art software? I've been experimenting with different tools and would love to hear your recommendations!",
            postType: .poll,
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            likeCount: 189,
            commentCount: 67,
            shareCount: 8,
            poll: Poll(
                question: "What's your favorite digital art software?",
                options: [
                    PollOption(text: "Procreate", voteCount: 145),
                    PollOption(text: "Adobe Photoshop", voteCount: 89),
                    PollOption(text: "Clip Studio Paint", voteCount: 67),
                    PollOption(text: "Other", voteCount: 23)
                ],
                endsAt: Calendar.current.date(byAdding: .day, value: 1, to: Date())
            ),
            tags: ["Art", "Software", "Poll"]
        ),
        CommunityPost(
            creatorId: User.sampleUsers[2].id,
            content: "🎮 LIVE NOW! Playing the new indie game that everyone's talking about. Come join the stream and let's explore this world together!",
            postType: .live,
            createdAt: Calendar.current.date(byAdding: .minute, value: -15, to: Date()) ?? Date(),
            likeCount: 89,
            commentCount: 234,
            shareCount: 45,
            tags: ["Gaming", "Live", "Stream"]
        ),
        CommunityPost(
            creatorId: User.sampleUsers[3].id,
            content: "🎉 MILESTONE ACHIEVED! We just hit 100K subscribers! I can't believe how far we've come. Thank you all for being part of this incredible journey. Special celebration video coming tomorrow! 🥳",
            postType: .milestone,
            createdAt: Calendar.current.date(byAdding: .hour, value: -6, to: Date()) ?? Date(),
            likeCount: 1234,
            commentCount: 456,
            shareCount: 123,
            tags: ["Milestone", "100K", "Celebration", "ThankYou"]
        ),
        CommunityPost(
            creatorId: User.sampleUsers[1].id,
            content: "Here's a quick behind-the-scenes look at my creative process! This piece took about 8 hours to complete. Swipe to see the progression from sketch to final artwork. ✨",
            imageURLs: [
                "https://picsum.photos/800/800?random=art1",
                "https://picsum.photos/800/800?random=art2", 
                "https://picsum.photos/800/800?random=art3"
            ],
            postType: .image,
            createdAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            likeCount: 345,
            commentCount: 78,
            shareCount: 23,
            tags: ["Art", "Process", "BehindTheScenes"]
        )
    ]
}

extension CommunityComment {
    static let sampleComments: [CommunityComment] = [
        CommunityComment(
            postId: CommunityPost.samplePosts[0].id,
            userId: User.sampleUsers[1].id,
            content: "This sounds amazing! Could you cover advanced animation techniques with matchedGeometryEffect?",
            createdAt: Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date(),
            likeCount: 12,
            isCreatorHeart: true
        ),
        CommunityComment(
            postId: CommunityPost.samplePosts[0].id,
            userId: User.sampleUsers[2].id,
            content: "Yes! Please include Core Data integration with SwiftUI 💪",
            createdAt: Calendar.current.date(byAdding: .minute, value: -45, to: Date()) ?? Date(),
            likeCount: 8
        ),
        CommunityComment(
            postId: CommunityPost.samplePosts[1].id,
            userId: User.sampleUsers[3].id,
            content: "Absolutely stunning! The colors are incredible 🌅",
            createdAt: Calendar.current.date(byAdding: .hour, value: -20, to: Date()) ?? Date(),
            likeCount: 23
        ),
        CommunityComment(
            postId: CommunityPost.samplePosts[4].id,
            userId: User.sampleUsers[0].id,
            content: "Congratulations! Well deserved! Your content is always top-notch 🎉",
            createdAt: Calendar.current.date(byAdding: .hour, value: -5, to: Date()) ?? Date(),
            likeCount: 45,
            isPinned: true
        )
    ]
}

#Preview {
    VStack(spacing: 20) {
        Text("Community System")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Community Features")
                .font(.headline)
            
            ForEach([
                "📝 Text, Image, Video, and Poll posts",
                "📌 Pin important announcements", 
                "💬 Nested comments with creator hearts",
                "📊 Real-time poll voting",
                "🏆 Milestone celebrations",
                "🔴 Live stream integration",
                "🏷️ Hashtag support",
                "📱 Rich media attachments"
            ], id: \.self) { feature in
                HStack {
                    Text(feature)
                        .font(.body)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        
        Spacer()
    }
    .padding()
}