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
                        CareerPathVideoCard(video: video, careerPathColor: careerPath.color)
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
        HStack(alignment: .center, spacing: 12) {
            // Career Path Icon
            ZStack {
                Circle()
                    .fill(careerPath.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: careerPath.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(careerPath.color)
            }
            
            // Career Info
            VStack(alignment: .leading, spacing: 4) {
                Text(careerPath.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                        Text("\(progress.videosWatched) videos")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("•")
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12, weight: .medium))
                        Text("\(Int(progress.totalHours))h watched")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            // Certificate Progress Badge
            if progress.certificateProgress > 0 {
                certificateProgressBadge
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var certificateProgressBadge: some View {
        VStack(spacing: 4) {
            Text("\(progress.progressPercentage)%")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(careerPath.color)
            
            Text("to Certificate")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(careerPath.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(careerPath.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Video Card

struct CareerPathVideoCard: View {
    let video: UniversityVideo
    let careerPathColor: Color
    
    private let cardWidth: CGFloat = 280
    private let cardHeight: CGFloat = 180
    
    @State private var prefetchedImage: UIImage?
    @State private var isPressed = false
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail with progress
            thumbnailSection
            
            // Video Info
            videoInfoSection
        }
        .frame(width: cardWidth)
        .padding(12)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(isPressed ? 0.12 : 0.08),
            radius: isPressed ? 16 : 12,
            x: 0,
            y: isPressed ? 6 : 4
        )
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
            // Thumbnail Image
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.cardBackground)
                    .overlay(
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    )
            }
            .frame(width: cardWidth - 24, height: 157)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Gradient Overlay (for better text visibility)
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Duration Badge
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(formatDuration(video.duration))
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.7))
            .clipShape(Capsule())
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            
            // Watch Progress Bar
            if video.watchProgress > 0 {
                watchProgressBar
            }
            
            // Completed Checkmark
            if video.completed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Completed")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.9))
                .clipShape(Capsule())
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
    
    private var watchProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
                
                Rectangle()
                    .fill(careerPathColor)
                    .frame(width: geometry.size.width * video.watchProgress, height: 4)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
    
    private var videoInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(video.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            // Creator & Stats
            HStack(spacing: 8) {
                // Creator Avatar
                AsyncImage(url: URL(string: video.creatorAvatarURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.cardBackground)
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                
                // Creator Name
                Text(video.creatorName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                
                Spacer()
                
                // AI Verification Badge
                if let aiScore = video.aiVerificationScore, aiScore >= 70 {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(aiScore)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(aiScore >= 90 ? .green : aiScore >= 80 ? .blue : .orange)
                }
            }
            
            // Skill Tags
            if !video.skillTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(video.skillTags.prefix(3), id: \.self) { skill in
                            Text(skill)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(careerPathColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(careerPathColor.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Difficulty Level
            HStack(spacing: 4) {
                Image(systemName: video.difficultyLevel.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(video.difficultyLevel.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(video.difficultyLevel.color)
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
    
    return ScrollView {
        CareerPathVideoRow(
            careerPath: sampleCareerPath,
            progress: sampleProgress,
            videos: sampleVideos
        ) { video in
            print("Tapped video: \(video.title)")
        }
    }
    .background(AppTheme.Colors.background)
}

