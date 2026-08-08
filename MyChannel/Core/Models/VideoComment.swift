//
//  VideoComment.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Video Comment Model
struct VideoComment: Identifiable, Codable {
    let id: String
    let author: User
    let text: String
    let likeCount: Int
    let replyCount: Int
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        author: User,
        text: String,
        likeCount: Int = 0,
        replyCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.author = author
        self.text = text
        self.likeCount = likeCount
        self.replyCount = replyCount
        self.createdAt = createdAt
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

extension VideoComment {
    static let sampleComments: [VideoComment] = [
        VideoComment(
            author: User.sampleUsers[1],
            text: "This video is absolutely amazing! The explanation was so clear and easy to follow. Thanks for sharing this knowledge!",
            likeCount: 156,
            replyCount: 12,
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
        ),
        VideoComment(
            author: User.sampleUsers[2],
            text: "Finally someone who actually knows what they're talking about. Subscribed! 🔥",
            likeCount: 89,
            replyCount: 5,
            createdAt: Calendar.current.date(byAdding: .hour, value: -4, to: Date()) ?? Date()
        ),
        VideoComment(
            author: User.sampleUsers[3],
            text: "Could you make a follow-up video covering the advanced techniques? This was super helpful!",
            likeCount: 34,
            replyCount: 3,
            createdAt: Calendar.current.date(byAdding: .hour, value: -6, to: Date()) ?? Date()
        ),
        VideoComment(
            author: User.sampleUsers[0],
            text: "The quality of your content keeps getting better. Keep up the great work! 👏",
            likeCount: 67,
            replyCount: 8,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        )
    ]
}

// MARK: - Comment Sort Option
enum CommentSortOption: String, CaseIterable {
    case topComments = "top"
    case newest = "time"
    
    var displayName: String {
        switch self {
        case .topComments: return "Top comments"
        case .newest: return "Newest first"
        }
    }

    /// Short label for compact pickers (e.g. segmented control).
    var pickerLabel: String {
        switch self {
        case .topComments: return "Top"
        case .newest: return "Newest"
        }
    }
}

// MARK: - Comments Manager
@MainActor
class CommentsManager: ObservableObject {
    @Published var comments: [VideoComment] = []
    @Published var isLoading = false
    
    func loadComments(for videoId: String, sortBy: CommentSortOption = .topComments) async throws -> [VideoComment] {
        isLoading = true
        defer { isLoading = false }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("comments")
            .whereField("videoId", isEqualTo: videoId)
            .order(by: sortBy == .newest ? "createdAt" : "likeCount", descending: true)
            .limit(to: 100)
            .getDocuments()
        let fetched = snap.documents.compactMap { try? $0.data(as: VideoComment.self) }
        await MainActor.run { self.comments = fetched }
        return fetched
        #else
        var result = VideoComment.sampleComments
        switch sortBy {
        case .topComments: result.sort { $0.likeCount > $1.likeCount }
        case .newest:      result.sort { $0.createdAt > $1.createdAt }
        }
        await MainActor.run { self.comments = result }
        return result
        #endif
    }

    /// Load all comments made on a creator's videos (for Studio Comments tab).
    func loadCommentsForCreator(creatorId: String) async throws -> [VideoComment] {
        isLoading = true
        defer { isLoading = false }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("comments")
            .whereField("creatorId", isEqualTo: creatorId)
            .order(by: "createdAt", descending: true)
            .limit(to: 200)
            .getDocuments()
        let fetched = snap.documents.compactMap { try? $0.data(as: VideoComment.self) }
        await MainActor.run { self.comments = fetched }
        return fetched
        #else
        let result = VideoComment.sampleComments.sorted { $0.createdAt > $1.createdAt }
        await MainActor.run { self.comments = result }
        return result
        #endif
    }
    
    func addComment(_ comment: VideoComment) {
        comments.insert(comment, at: 0)
    }
    
    func likeComment(_ commentId: String) {
        // Handle comment like
    }
    
    func replyToComment(_ commentId: String, reply: String) {
        // Handle comment reply
    }
}
// MARK: - Shared Instance
extension CommentsManager {
    static let shared = CommentsManager()
}
