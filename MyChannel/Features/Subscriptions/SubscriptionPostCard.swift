//
//  SubscriptionPostCard.swift
//  MyChannel
//
//  YouTube-style community Posts card for the subscriptions feed.
//

import SwiftUI

struct SubscriptionPostCard: View {
    let item: SubscriptionPost
    var onOpenChannel: (User) -> Void = { _ in }
    
    private var post: CommunityPost { item.post }
    private var author: User { item.author }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: author + time
            Button {
                HapticManager.shared.impact(style: .light)
                onOpenChannel(author)
            } label: {
                HStack(spacing: 10) {
                    CachedAsyncImage(url: URL(string: author.profileImageURL ?? "")) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            )
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(author.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .lineLimit(1)
                            if author.shouldShowVerificationBadge {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                        HStack(spacing: 5) {
                            Image(systemName: post.postType.iconName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            Text(post.createdAt.timeAgoDisplay)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            // Content
            if !post.content.isEmpty {
                Text(post.content)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Image attachment
            if let imageURL = post.imageURLs.first, !imageURL.isEmpty {
                CachedAsyncImage(url: URL(string: imageURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(ProgressView())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Poll preview
            if let poll = post.poll {
                pollPreview(poll)
            }
            
            // Engagement row
            HStack(spacing: 20) {
                Label("\(formatCount(post.likeCount))", systemImage: "hand.thumbsup")
                Label("\(formatCount(post.commentCount))", systemImage: "bubble.right")
                Spacer()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
        )
    }
    
    private func pollPreview(_ poll: Poll) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(poll.options.prefix(4)) { option in
                let pct = poll.totalVotes > 0 ? Double(option.voteCount) / Double(poll.totalVotes) : 0
                ZStack(alignment: .leading) {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.Colors.primary.opacity(0.18))
                            .frame(width: max(0, geo.size.width * pct))
                    }
                    HStack {
                        Text(option.text)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Spacer()
                        Text("\(Int(pct * 100))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.Colors.background))
            }
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}
