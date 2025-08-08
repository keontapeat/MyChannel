//  VideoDetailMetaView.swift
//  MyChannel

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
                // MARK: - Title
                Text(video.title)
                    .font(AppTheme.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal)

                // MARK: - Stats
                HStack {
                    Text("\(video.formattedViewCount) views")
                    Text("•")
                    Text(video.timeAgo)
                }
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(.horizontal)

                // MARK: - Action Buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 32) {
                        MetaActionButton(icon: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup", title: "\(video.likeCount)", color: isLiked ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary) {
                            withAnimation(.spring()) {
                                isLiked.toggle()
                                if isLiked { isDisliked = false }
                            }
                            HapticManager.shared.impact(style: .light)
                        }

                        MetaActionButton(icon: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown", title: "Dislike", color: isDisliked ? AppTheme.Colors.error : AppTheme.Colors.textSecondary) {
                            withAnimation(.spring()) {
                                isDisliked.toggle()
                                if isDisliked { isLiked = false }
                            }
                            HapticManager.shared.impact(style: .light)
                        }

                        MetaActionButton(icon: "square.and.arrow.up", title: "Share") {
                            onShare()
                            HapticManager.shared.impact(style: .light)
                        }

                        MetaActionButton(icon: isWatchLater ? "bookmark.fill" : "bookmark", title: "Save", color: isWatchLater ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary) {
                            withAnimation(.spring()) {
                                isWatchLater.toggle()
                            }
                            HapticManager.shared.impact(style: .light)
                        }

                        MetaActionButton(icon: "ellipsis", title: "More") {
                            onMore()
                            HapticManager.shared.impact(style: .light)
                        }
                    }
                    .padding(.horizontal)
                }

                Divider().padding(.horizontal)

                // MARK: - Creator
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
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

                // MARK: - Description
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

                // MARK: - Tags
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

                // MARK: - Comments
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

                Spacer(minLength: 120)
            }
        }
        .background(AppTheme.Colors.background)
    }
}

struct MetaActionButton: View {
    let icon: String
    let title: String
    var color: Color = AppTheme.Colors.textSecondary
    let action: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .onTapGesture {
            action()
        }
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