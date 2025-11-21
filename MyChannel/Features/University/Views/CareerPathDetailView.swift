//
//  CareerPathDetailView.swift
//  MyChannel
//
//  Detailed view for a specific career path showing all videos,
//  progress, requirements, top creators, and certificate info
//

import SwiftUI

struct CareerPathDetailView: View {
    let careerPath: CareerPath
    let progress: CareerPathProgress
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: VideoFilter = .all
    @State private var scrollOffset: CGFloat = 0
    
    enum VideoFilter: String, CaseIterable {
        case all = "All"
        case incomplete = "In Progress"
        case completed = "Completed"
        case recommended = "Recommended"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with Progress
                headerSection
                
                // Certificate Progress
                certificateProgressSection
                
                // Filter Tabs
                filterTabsSection
                
                // Videos Grid
                videosGridSection
            }
            .padding(.vertical, 24)
        }
        .background(AppTheme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                shareButton
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Career Icon & Name
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(careerPath.color.opacity(0.15))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: careerPath.icon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(careerPath.color)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(careerPath.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text("\(progress.videosWatched) videos watched")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            // Description
            Text(careerPath.description)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineLimit(3)
            
            // Stats Row
            HStack(spacing: 16) {
                statPill(icon: "clock.fill", value: "\(Int(progress.totalHours))h", label: "Watched", color: careerPath.color)
                statPill(icon: "checkmark.circle.fill", value: "\(progress.progressPercentage)%", label: "Progress", color: .green)
                statPill(icon: "medal.fill", value: "\(progress.videosRemaining)", label: "To Certificate", color: .orange)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(value)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Certificate Progress Section
    
    private var certificateProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Certificate Progress")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 20)
            
            CertificateProgressCard(careerPath: careerPath, progress: progress) {
                // Show certificate detail or requirements
                print("Show certificate requirements")
            }
            .padding(.horizontal, 20)
            
            // Requirements List
            VStack(alignment: .leading, spacing: 12) {
                requirementRow(
                    icon: "play.circle.fill",
                    title: "Videos Watched",
                    current: progress.videosWatched,
                    required: careerPath.certificateRequirement.minimumVideos,
                    color: careerPath.color
                )
                
                requirementRow(
                    icon: "clock.fill",
                    title: "Hours Completed",
                    current: Int(progress.totalHours),
                    required: Int(careerPath.certificateRequirement.minimumHours),
                    color: careerPath.color
                )
                
                requirementRow(
                    icon: "checkmark.shield.fill",
                    title: "AI Verification Score",
                    current: progress.averageAIScore,
                    required: careerPath.certificateRequirement.minimumAIScore,
                    color: careerPath.color
                )
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(careerPath.color.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }
    
    private func requirementRow(icon: String, title: String, current: Int, required: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                HStack(spacing: 6) {
                    Text("\(current)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                    
                    Text("/ \(required) required")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            // Check mark if completed
            if current >= required {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.green)
            }
        }
    }
    
    // MARK: - Filter Tabs Section
    
    private var filterTabsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(VideoFilter.allCases, id: \.self) { filter in
                    filterTabButton(filter)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func filterTabButton(_ filter: VideoFilter) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedFilter = filter
            }
            HapticManager.shared.impact(style: .light)
        }) {
            Text(filter.rawValue)
                .font(.system(size: 15, weight: selectedFilter == filter ? .bold : .semibold))
                .foregroundColor(selectedFilter == filter ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(selectedFilter == filter ? careerPath.color : AppTheme.Colors.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(selectedFilter == filter ? Color.clear : AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Videos Grid Section
    
    private var videosGridSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            // Mock videos - in production, filter based on selectedFilter
            ForEach(0..<10, id: \.self) { index in
                videoGridCard(mockVideo(index: index))
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func mockVideo(index: Int) -> UniversityVideo {
        UniversityVideo(
            id: "\(index)",
            videoId: "vid\(index)",
            title: "\(careerPath.name): Lesson \(index + 1) - Advanced Concepts",
            thumbnailURL: "https://picsum.photos/400/\(225 + index)",
            duration: TimeInterval(1200 + index * 300),
            creatorId: "creator\(index)",
            creatorName: "Expert Teacher",
            creatorAvatarURL: "https://picsum.photos/\(100 + index)/100",
            careerPaths: [careerPath.id],
            skillTags: Array(careerPath.skillTags.prefix(2)),
            difficultyLevel: [.beginner, .intermediate, .advanced].randomElement() ?? .intermediate,
            isUniversityContent: true,
            certificateEligible: true,
            aiCategorizationScore: Double.random(in: 0.8...0.99),
            watchProgress: index < 3 ? Double.random(in: 0.1...0.7) : 0.0,
            lastWatchedAt: index < 3 ? Date() : nil,
            aiVerificationScore: Int.random(in: 75...95),
            completed: index < 2
        )
    }
    
    private func videoGridCard(_ video: UniversityVideo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Thumbnail
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(careerPath.color.opacity(0.1))
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Duration Badge
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(formatDuration(video.duration))
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.7))
                .clipShape(Capsule())
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                
                // Progress Bar
                if video.watchProgress > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 3)
                            
                            Rectangle()
                                .fill(careerPath.color)
                                .frame(width: geometry.size.width * video.watchProgress, height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }
            }
            
            // Title
            Text(video.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)
            
            // Creator & Duration
            HStack(spacing: 4) {
                Text(video.creatorName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                
                if video.completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(10)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(careerPath.color.opacity(0.2), lineWidth: 1)
        )
        .onTapGesture {
            print("Play video: \(video.title)")
            // TODO: Play video
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
    
    // MARK: - Share Button
    
    private var shareButton: some View {
        Button(action: {
            print("Share career path progress")
            // TODO: Share to social media
        }) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(careerPath.color)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CareerPathDetailView(
            careerPath: CareerPath.allCareerPaths[0],
            progress: CareerPathProgress(
                id: "1",
                userId: "user1",
                careerPathId: CareerPath.allCareerPaths[0].id,
                totalHours: 187.5,
                videosWatched: 224,
                videoIds: [],
                lastWatchedAt: Date(),
                certificateProgress: 0.75,
                certificateEarned: false,
                certificateEarnedDate: nil,
                averageAIScore: 88,
                skillsCovered: []
            )
        )
    }
}




