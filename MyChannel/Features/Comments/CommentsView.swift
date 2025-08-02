//
//  CommentsView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct CommentsView: View {
    let video: Video
    @State private var comments: [Comment] = Comment.sampleComments
    @State private var newComment: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Video info header
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 60, height: 34)
                    .cornerRadius(AppTheme.CornerRadius.sm)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(video.title)
                            .font(AppTheme.Typography.subheadline)
                            .lineLimit(2)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("\(video.commentCount) comments")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(AppTheme.Colors.surface)
                
                // Comments list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(comments) { comment in
                            CommentCard(comment: comment)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                
                // Comment input
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: User.sampleUsers[0].profileImageURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    
                    TextField("Add a comment...", text: $newComment)
                        .font(AppTheme.Typography.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(AppTheme.CornerRadius.md)
                    
                    Button("Post") {
                        // Handle post comment
                        newComment = ""
                    }
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundColor(AppTheme.Colors.primary)
                    .disabled(newComment.isEmpty)
                }
                .padding()
                .background(AppTheme.Colors.background)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CommentCard: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: comment.author.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(AppTheme.Colors.surface)
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(comment.author.displayName)
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    if comment.author.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    
                    Text(comment.createdAt.timeAgoDisplay)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Spacer()
                }
                
                Text(comment.content)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                HStack(spacing: 16) {
                    Button(action: {}) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart")
                                .font(.system(size: 14))
                            
                            Text("\(comment.likeCount)")
                                .font(AppTheme.Typography.caption)
                        }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Button("Reply") {
                        // Handle reply
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                }
            }
        }
    }
}

struct Comment: Identifiable {
    let id: String = UUID().uuidString
    let content: String
    let author: User
    let createdAt: Date
    let likeCount: Int
    let replies: [Comment]
    
    static let sampleComments: [Comment] = [
        Comment(
            content: "This is an amazing tutorial! Really helped me understand SwiftUI better.",
            author: User.sampleUsers[1],
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
            likeCount: 24,
            replies: []
        ),
        Comment(
            content: "Thanks for sharing this! Could you do a follow-up on advanced techniques?",
            author: User.sampleUsers[2],
            createdAt: Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date(),
            likeCount: 12,
            replies: []
        ),
        Comment(
            content: "Great explanation of the concepts. Looking forward to more content like this!",
            author: User.sampleUsers[3],
            createdAt: Calendar.current.date(byAdding: .minute, value: -30, to: Date()) ?? Date(),
            likeCount: 8,
            replies: []
        )
    ]
}

#Preview {
    CommentsView(video: Video.sampleVideos[0])
}