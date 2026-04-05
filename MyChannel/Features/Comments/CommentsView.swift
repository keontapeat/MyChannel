//
//  CommentsView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct CommentsView: View {
    let video: Video

    var body: some View {
        NavigationStack {
            RealTimeCommentsView(video: video)
                .navigationTitle("Comments")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CommentCard: View {
    let comment: VideoComment
    
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
                
                        Text(comment.text)
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

// VideoComment model is now in Core/Models/VideoComment.swift

#Preview {
    CommentsView(video: Video.sampleVideos[0])
}