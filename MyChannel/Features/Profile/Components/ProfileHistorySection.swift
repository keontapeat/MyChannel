//
//  ProfileHistorySection.swift
//  MyChannel
//
//  Extracted from ProfileView.swift for better maintainability
//

import SwiftUI

// MARK: - History Section (horizontal carousel like YouTube)

struct ProfileHistorySection: View {
    let title: String
    let videos: [Video]
    var onViewAll: () -> Void

    @State private var appear = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()

                if !videos.isEmpty {
                    Button(action: onViewAll) {
                        Text("View all")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.backgroundSecondary.opacity(0.6))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            if videos.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("No watch history yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("Videos you watch will appear here")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(videos) { video in
                            HistoryVideoCard(video: video)
                                .frame(width: 280)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                }
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.04),
                            .init(color: .black, location: 0.96),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
        }
        .onAppear {
            if !appear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    appear = true
                }
            }
        }
    }
}

// MARK: - History Video Card

struct HistoryVideoCard: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.backgroundSecondary.opacity(0.6))

                AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            LinearGradient(colors: [AppTheme.Colors.backgroundSecondary, AppTheme.Colors.background], startPoint: .top, endPoint: .bottom)
                            ProgressView()
                                .tint(AppTheme.Colors.primary)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    case .failure:
                        ZStack {
                            Color.gray.opacity(0.25)
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 160)
                .overlay(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.25)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )

                Text(video.duration.formattedAsTimestamp())
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text(video.creator.displayName)
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            HapticManager.shared.impact(style: .light)
            NotificationCenter.default.post(name: .openVideoFromHistory, object: video)
        }
    }
}

// MARK: - Previews

#Preview("History Section") {
    ProfileHistorySection(
        title: "History",
        videos: Array(Video.sampleVideos.prefix(6))
    ) { }
    .padding()
    .background(AppTheme.Colors.background)
}

#Preview("History Section - Empty") {
    ProfileHistorySection(
        title: "History",
        videos: []
    ) { }
    .padding()
    .background(AppTheme.Colors.background)
}

#Preview("History Video Card") {
    HistoryVideoCard(video: Video.sampleVideos.first!)
        .frame(width: 280)
        .padding()
        .background(AppTheme.Colors.background)
}







