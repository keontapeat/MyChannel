//
//  ContinueLearningSection.swift
//  MyChannel
//
//  Featured section for incomplete videos user can continue watching
//  Premium Apple TV+ style with prominent "Continue" actions
//

import SwiftUI

struct ContinueLearningSection: View {
    let videos: [ContinueLearningVideo]
    let onContinue: (ContinueLearningVideo) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            sectionHeader
            
            // Videos
            VStack(spacing: 16) {
                ForEach(videos) { video in
                    ContinueLearningCard(video: video) {
                        HapticManager.shared.impact(style: .medium)
                        onContinue(video)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var sectionHeader: some View {
        EmptyView()
    }
}

// MARK: - Continue Learning Card

struct ContinueLearningCard: View {
    let video: ContinueLearningVideo
    let onContinue: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onContinue) {
            HStack(spacing: 12) {
                thumbnailSection
                videoInfoSection
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    private var thumbnailSection: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: video.video.thumbnailURL)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(Color(.tertiaryLabel))
                    )
            }
            .frame(width: 128, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Red YouTube-style progress bar at bottom
            GeometryReader { _ in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.25)).frame(height: 3)
                    Rectangle()
                        .fill(UniversityTheme.Colors.accent)
                        .frame(width: 128 * video.progressPercentage, height: 3)
                }
            }
            .frame(width: 128, height: 3)
        }
    }
    
    private var videoInfoSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(video.careerPathName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(.secondaryLabel))
                .lineLimit(1)

            Text(video.video.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.label))
                .lineLimit(2)

            Text(video.video.creatorName)
                .font(.system(size: 12))
                .foregroundColor(Color(.secondaryLabel))
                .lineLimit(1)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text(video.timeRemainingText)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(Color(.tertiaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty State

struct ContinueLearningEmptyState: View {
    let onExplore: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(Color(.tertiaryLabel))

            Text("No Videos in Progress")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(.secondaryLabel))

            Button(action: onExplore) {
                Text("Explore Career Paths")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(UniversityTheme.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    let sampleVideos = [
        ContinueLearningVideo(
            id: "1",
            video: UniversityVideo(
                id: "1",
                videoId: "vid1",
                title: "Advanced Swift Patterns: Protocol-Oriented Programming",
                thumbnailURL: "https://picsum.photos/400/225",
                duration: 2400,
                creatorId: "creator1",
                creatorName: "iOS Academy",
                creatorAvatarURL: "https://picsum.photos/100/100",
                careerPaths: ["ios-development"],
                skillTags: ["Swift", "Protocols", "Design Patterns"],
                difficultyLevel: .advanced,
                isUniversityContent: true,
                certificateEligible: true,
                aiCategorizationScore: 0.95,
                watchProgress: 0.65,
                lastWatchedAt: Date(),
                aiVerificationScore: 92,
                completed: false
            ),
            careerPathId: "ios-development",
            careerPathName: "iOS Development",
            careerPathColor: Color(red: 0.0, green: 0.5, blue: 0.9),
            progressPercentage: 0.65,
            timeRemaining: 840,
            lastWatchedAt: Date().addingTimeInterval(-3600)
        ),
        ContinueLearningVideo(
            id: "2",
            video: UniversityVideo(
                id: "2",
                videoId: "vid2",
                title: "SwiftUI Navigation Best Practices",
                thumbnailURL: "https://picsum.photos/401/225",
                duration: 1800,
                creatorId: "creator2",
                creatorName: "Swift Mastery",
                creatorAvatarURL: "https://picsum.photos/101/100",
                careerPaths: ["ios-development"],
                skillTags: ["SwiftUI", "Navigation"],
                difficultyLevel: .intermediate,
                isUniversityContent: true,
                certificateEligible: true,
                aiCategorizationScore: 0.88,
                watchProgress: 0.45,
                lastWatchedAt: Date().addingTimeInterval(-7200),
                aiVerificationScore: 85,
                completed: false
            ),
            careerPathId: "ios-development",
            careerPathName: "iOS Development",
            careerPathColor: Color(red: 0.0, green: 0.5, blue: 0.9),
            progressPercentage: 0.45,
            timeRemaining: 990,
            lastWatchedAt: Date().addingTimeInterval(-7200)
        )
    ]
    
    ScrollView {
        VStack(spacing: 24) {
            ContinueLearningSection(videos: sampleVideos) { video in
                print("Continue: \(video.video.title)")
            }
            
            Divider()
                .padding(.vertical)
            
            ContinueLearningEmptyState {
                print("Explore tapped")
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
    }
    .background(Color(.systemBackground))
}






