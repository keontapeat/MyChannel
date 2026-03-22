//
//  SeeAllCategoriesView.swift
//  MyChannel
//
//  Full-screen browse-by-category view launched from Home "Categories" See All
//

import SwiftUI

struct SeeAllCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let initialVideos: [Video]

    enum Category: String, CaseIterable {
        case all = "All"
        case music = "Music"
        case gaming = "Gaming"
        case sports = "Sports"
        case news = "News"
        case tech = "Tech"
        case entertainment = "Entertainment"
        case education = "Education"
        case comedy = "Comedy"
    }

    @State private var selection: Category = .all
    @State private var allVideos: [Video] = []

    private var filtered: [Video] {
        switch selection {
        case .all:
            return allVideos
        case .music:
            return allVideos.filter { $0.category == .music }
        case .gaming:
            return allVideos.filter { $0.category == .gaming }
        case .sports:
            return allVideos.filter { $0.category == .sports }
        case .news:
            return allVideos.filter { $0.category == .news }
        case .tech:
            return allVideos.filter { $0.category == .technology }
        case .entertainment:
            return allVideos.filter { $0.category == .entertainment }
        case .education:
            return allVideos.filter { $0.category == .education }
        case .comedy:
            return allVideos.filter { $0.category == .comedy }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Category.allCases, id: \.self) { cat in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    selection = cat
                                }
                                HapticManager.shared.selection()
                            } label: {
                                Text(cat.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(selection == cat ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(selection == cat ? AppTheme.Colors.primary : Color(.systemGray6))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }

                Divider()

                // Video grid
                if filtered.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No videos in this category")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filtered) { video in
                                CategoryVideoCard(video: video) {
                                    NotificationCenter.default.post(
                                        name: Notification.Name("PlayVideoFromCategories"),
                                        object: video
                                    )
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.Colors.surface, in: Circle())
                    }
                }
            }
        }
        .onAppear {
            loadAllVideos()
        }
    }

    private func loadAllVideos() {
        // Combine initial videos with seed catalog and sample videos, deduplicated
        var combined = initialVideos + SeedCatalogService.shared.seedVideos + Video.sampleVideos
        var seen = Set<String>()
        combined = combined.filter { v in
            if seen.contains(v.id) { return false }
            seen.insert(v.id)
            return true
        }
        allVideos = combined
    }
}

// MARK: - Category Video Card
private struct CategoryVideoCard: View {
    let video: Video
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                ZStack(alignment: .bottomTrailing) {
                    AppAsyncImage(url: video.posterCandidates.first) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                            )
                    }
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    // Duration badge
                    if video.duration > 0 {
                        Text(formatDuration(video.duration))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                    }
                }

                // Title
                Text(video.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Creator + views
                HStack(spacing: 4) {
                    Text(video.creator.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if video.viewCount > 0 {
                        Text("•")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                        Text(formatViews(video.viewCount))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatViews(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM views", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK views", Double(count) / 1_000)
        }
        return "\(count) views"
    }
}

#Preview {
    SeeAllCategoriesView(initialVideos: Video.sampleVideos)
        .environmentObject(AppState())
}
