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
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
            
            Text("Continue Learning")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
            
            // Total time remaining badge
            if !videos.isEmpty {
                let totalMinutes = videos.map { Int($0.timeRemaining / 60) }.reduce(0, +)
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12, weight: .medium))
                    Text("\(totalMinutes) min left")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.Colors.surface)
                .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Continue Learning Card

struct ContinueLearningCard: View {
    let video: ContinueLearningVideo
    let onContinue: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onContinue) {
            HStack(spacing: 16) {
                // Thumbnail with Progress
                thumbnailSection
                
                // Video Info
                videoInfoSection
                
                // Continue Button
                continueButton
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(video.careerPathColor.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: video.careerPathColor.opacity(0.15), radius: 16, x: 0, y: 8)
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
        ZStack(alignment: .center) {
            // Thumbnail
            AsyncImage(url: URL(string: video.video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(video.careerPathColor.opacity(0.1))
                    .overlay(
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(video.careerPathColor.opacity(0.3))
                    )
            }
            .frame(width: 140, height: 85)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Play Icon Overlay
            Circle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 2)
                )
            
            // Progress Ring
            progressRing
        }
    }
    
    private var progressRing: some View {
        Circle()
            .trim(from: 0, to: video.progressPercentage)
            .stroke(
                video.careerPathColor,
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: 44, height: 44)
            .rotationEffect(.degrees(-90))
            .animation(.spring(response: 1.0, dampingFraction: 0.8), value: video.progressPercentage)
    }
    
    private var videoInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Career Path Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(video.careerPathColor)
                    .frame(width: 6, height: 6)
                
                Text(video.careerPathName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(video.careerPathColor)
            }
            
            // Video Title
            Text(video.video.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Creator
            HStack(spacing: 6) {
                AsyncImage(url: URL(string: video.video.creatorAvatarURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.cardBackground)
                }
                .frame(width: 18, height: 18)
                .clipShape(Circle())
                
                Text(video.video.creatorName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            // Progress & Time
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11, weight: .medium))
                    Text(video.timeRemainingText)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("•")
                    .foregroundColor(AppTheme.Colors.textTertiary)
                
                Text(video.progressText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(video.careerPathColor)
            }
        }
    }
    
    private var continueButton: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(video.careerPathColor)
            
            Text("Continue")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(video.careerPathColor)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Empty State

struct ContinueLearningEmptyState: View {
    let onExplore: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            VStack(spacing: 8) {
                Text("No Videos in Progress")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Start watching videos to build your learning path")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onExplore) {
                HStack(spacing: 8) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Explore Career Paths")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.primary)
                .clipShape(Capsule())
                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 4)
            }
        }
        .padding(.vertical, 40)
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
    
    return ScrollView {
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
    .background(AppTheme.Colors.background)
}

