//
//  VideoDetailMetaView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct VideoDetailMetaView: View {
    let video: Video
    @Binding var isSubscribed: Bool
    @Binding var isWatchLater: Bool
    @Binding var isLiked: Bool
    @Binding var isDisliked: Bool
    @Binding var expandedDescription: Bool
    let onShare: () -> Void
    let onMore: () -> Void
    let onComment: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Video Title
                Text(video.title)
                    .font(AppTheme.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal)
                
                // Video Stats
                HStack {
                    Text("\(video.formattedViewCount) views")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("•")
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text(video.timeAgo)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Action Buttons
                HStack(spacing: 24) {
                    // Like Button
                    Button(action: {
                        withAnimation(.spring()) {
                            isLiked.toggle()
                            if isLiked && isDisliked {
                                isDisliked = false
                            }
                        }
                        HapticManager.shared.impact(style: .light)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.title2)
                                .foregroundColor(isLiked ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                            
                            Text("\(video.likeCount)")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    
                    // Dislike Button
                    Button(action: {
                        withAnimation(.spring()) {
                            isDisliked.toggle()
                            if isDisliked && isLiked {
                                isLiked = false
                            }
                        }
                        HapticManager.shared.impact(style: .light)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                .font(.title2)
                                .foregroundColor(isDisliked ? AppTheme.Colors.error : AppTheme.Colors.textSecondary)
                            
                            Text("Dislike")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    
                    // Share Button
                    Button(action: {
                        onShare()
                        HapticManager.shared.impact(style: .light)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Text("Share")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    
                    // Save Button
                    Button(action: {
                        withAnimation(.spring()) {
                            isWatchLater.toggle()
                        }
                        HapticManager.shared.impact(style: .light)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: isWatchLater ? "bookmark.fill" : "bookmark")
                                .font(.title2)
                                .foregroundColor(isWatchLater ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                            
                            Text("Save")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    
                    // More Button
                    Button(action: {
                        onMore()
                        HapticManager.shared.impact(style: .light)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "ellipsis")
                                .font(.title2)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Text("More")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Divider
                Divider()
                    .padding(.horizontal)
                
                // Creator Info
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(video.creator.displayName)
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            if video.creator.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .font(.caption)
                            }
                        }
                        
                        Text("\(video.creator.subscriberCount.formatted()) subscribers")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            isSubscribed.toggle()
                        }
                        HapticManager.shared.impact(style: .medium)
                    }) {
                        Text(isSubscribed ? "Subscribed" : "Subscribe")
                            .font(AppTheme.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(isSubscribed ? AppTheme.Colors.textSecondary : .white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(isSubscribed ? AppTheme.Colors.surface : AppTheme.Colors.primary)
                            )
                    }
                }
                .padding(.horizontal)
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text(expandedDescription ? video.description : String(video.description.prefix(100)) + (video.description.count > 100 ? "..." : ""))
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if video.description.count > 100 {
                        Button(expandedDescription ? "Show less" : "Show more") {
                            withAnimation(.easeInOut) {
                                expandedDescription.toggle()
                            }
                        }
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                .padding(.horizontal)
                
                // Tags
                if !video.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(video.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(AppTheme.Colors.primary.opacity(0.1))
                                    )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Comments Section Header
                HStack {
                    Text("Comments")
                        .font(AppTheme.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("\(video.commentCount)")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                    
                    Button(action: onComment) {
                        Image(systemName: "plus")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Add some bottom padding for the mini player
                Spacer(minLength: 120)
            }
        }
        .background(AppTheme.Colors.background)
    }
}

#Preview {
    VideoDetailMetaView(
        video: Video.sampleVideos[0],
        isSubscribed: .constant(false),
        isWatchLater: .constant(false),
        isLiked: .constant(false),
        isDisliked: .constant(false),
        expandedDescription: .constant(false),
        onShare: {},
        onMore: {},
        onComment: {}
    )
}