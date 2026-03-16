//
//  CareerPathVideoRow.swift
//  MyChannel
//
//  Netflix/Apple TV+ Style Horizontal Scrolling Video Row
//  Premium Modern Design for Career Path Videos
//

import SwiftUI

struct CareerPathVideoRow: View {
    let careerPath: CareerPath
    let progress: CareerPathProgress
    let videos: [UniversityVideo]
    let onVideoTap: (UniversityVideo) -> Void
    
    @State private var scrollOffset: CGFloat = 0
    @State private var visibleCardIndices: Set<Int> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            rowHeader
            
            // 🔥 NUCLEAR: Horizontal Scrolling with Lazy Loading & Prefetching
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                        CareerPathVideoCard(video: video)
                            .onTapGesture {
                                HapticManager.shared.impact(style: .light)
                                onVideoTap(video)
                            }
                            .onAppear {
                                // 🔥 PREFETCH: Prefetch next 3 video thumbnails
                                prefetchNextVideos(currentIndex: index)
                                visibleCardIndices.insert(index)
                            }
                            .onDisappear {
                                visibleCardIndices.remove(index)
                            }
                            // 🔥 ANIMATION: Staggered appearance
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.03), value: visibleCardIndices.contains(index))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 12)
        // 🔥 ACCESSIBILITY: Announce row content
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(careerPath.name) video row")
        .accessibilityHint("Swipe left or right to browse \(videos.count) videos")
    }
    
    // MARK: - Image Prefetching
    
    private func prefetchNextVideos(currentIndex: Int) {
        let nextIndices = (currentIndex + 1)...(currentIndex + 3)
        let nextURLs = nextIndices.compactMap { index in
            videos.indices.contains(index) ? videos[index].thumbnailURL : nil
        }
        
        let urls = nextURLs.compactMap { URL(string: $0) }
        ImagePrefetcher.shared.prefetch(urls: urls)
    }
    
    // MARK: - Row Header
    
    private var rowHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: careerPath.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(.label))
                .frame(width: 36, height: 36)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(careerPath.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(.label))

                HStack(spacing: 6) {
                    Text("\(progress.videosWatched) watched")
                    Text("·")
                    Text("\(Int(progress.totalHours))h")
                    Text("·")
                    Text("\(progress.progressPercentage)% to cert")
                }
                .font(.system(size: 12))
                .foregroundColor(Color(.secondaryLabel))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Video Card

struct CareerPathVideoCard: View {
    let video: UniversityVideo

    private let cardWidth: CGFloat = 280
    private let cardHeight: CGFloat = 180
    
    @State private var prefetchedImage: UIImage?
    @State private var isPressed = false
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            thumbnailSection
            videoInfoSection
        }
        .frame(width: cardWidth)
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onAppear {
            // Prefetch next images for smooth scrolling
            // Note: Image prefetching is handled by prefetchNextVideos in the parent view
        }
        // 🔥 ACCESSIBILITY: Comprehensive video card labels
        .accessibilityElement(children: .combine)
        .accessibilityLabel(videoAccessibilityLabel)
        .accessibilityHint("Double tap to watch video")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Accessibility
    
    private var videoAccessibilityLabel: String {
        var label = video.title
        label += ", Duration \(formatDuration(video.duration))"
        label += ", by \(video.creatorName)"
        
        if video.completed {
            label += ", Completed"
        } else if video.watchProgress > 0 {
            label += ", \(Int(video.watchProgress * 100))% watched"
        }
        
        if let aiScore = video.aiVerificationScore, aiScore >= 70 {
            label += ", AI verified score \(aiScore)"
        }
        
        label += ", Difficulty: \(video.difficultyLevel.rawValue)"
        
        return label
    }
    
    private var thumbnailSection: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(Color(.tertiaryLabel))
                    )
            }
            .frame(width: cardWidth - 20, height: 148)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Duration pill
            Text(formatDuration(video.duration))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            // Completed badge
            if video.completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(UniversityTheme.Colors.verified)
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            // Red YouTube-style progress bar
            if video.watchProgress > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.2)).frame(height: 3)
                        Rectangle()
                            .fill(UniversityTheme.Colors.accent)
                            .frame(width: geo.size.width * video.watchProgress, height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
    }
    
    private var videoInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(video.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.label))
                .lineLimit(2)

            HStack(spacing: 6) {
                Text(video.creatorName)
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabel))
                    .lineLimit(1)

                Spacer()

                if let aiScore = video.aiVerificationScore, aiScore >= 70 {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(aiScore)")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(UniversityTheme.Colors.verified)
                }
            }

            if !video.skillTags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(video.skillTags.prefix(2), id: \.self) { skill in
                        Text(skill)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(.secondaryLabel))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleCareerPath = CareerPath.allCareerPaths[0]
    let sampleProgress = CareerPathProgress(
        id: "1",
        userId: "user1",
        careerPathId: sampleCareerPath.id,
        totalHours: 145.5,
        videosWatched: 187,
        videoIds: [],
        lastWatchedAt: Date(),
        certificateProgress: 0.62,
        certificateEarned: false,
        certificateEarnedDate: nil,
        averageAIScore: 85,
        skillsCovered: ["Accounting", "Tax", "Excel"]
    )
    
    let sampleVideos = (0..<5).map { index in
        UniversityVideo(
            id: "\(index)",
            videoId: "vid\(index)",
            title: "Advanced Accounting Principles: Understanding Financial Statements",
            thumbnailURL: "https://picsum.photos/400/225",
            duration: TimeInterval(1200 + index * 300),
            creatorId: "creator1",
            creatorName: "Finance Pro",
            creatorAvatarURL: "https://picsum.photos/100/100",
            careerPaths: [sampleCareerPath.id],
            skillTags: ["Accounting", "Financial Analysis", "Excel"],
            difficultyLevel: .intermediate,
            isUniversityContent: true,
            certificateEligible: true,
            aiCategorizationScore: 0.95,
            watchProgress: index == 0 ? 0.65 : index == 1 ? 0.0 : 0.0,
            lastWatchedAt: index == 0 ? Date() : nil,
            aiVerificationScore: 88,
            completed: index == 2
        )
    }
    
    ScrollView {
        CareerPathVideoRow(
            careerPath: sampleCareerPath,
            progress: sampleProgress,
            videos: sampleVideos
        ) { video in
            print("Tapped video: \(video.title)")
        }
    }
    .background(Color(.systemBackground))
}

