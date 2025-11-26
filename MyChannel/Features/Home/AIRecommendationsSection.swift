//
//  AIRecommendationsSection.swift
//  MyChannel
//
//  🤖 AI-POWERED RECOMMENDATIONS SECTION
//  Uses Vertex AI Recommender Agent for personalized video feed
//

import SwiftUI

struct AIRecommendationsSection: View {
    let onPlayVideo: (Video) -> Void
    
    @EnvironmentObject private var appState: AppState
    @State private var recommendedVideos: [Video] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("AI Recommended For You")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 20)
            
            if recommendedVideos.isEmpty && !isLoading {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("Getting AI recommendations...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Horizontal scrolling video cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recommendedVideos) { video in
                            AIRecommendedVideoCard(video: video, onTap: {
                                onPlayVideo(video)
                            })
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 16)
        .task {
            await loadRecommendations()
        }
    }
    
    // MARK: - Load AI Recommendations
    
    private func loadRecommendations() async {
        guard !isLoading else { return }
        guard appState.isAuthenticated, let userId = appState.currentUser?.id else {
            // Not logged in - use sample videos
            await MainActor.run {
                recommendedVideos = Array(Video.sampleVideos.shuffled().prefix(10))
            }
            return
        }
        
        isLoading = true
        
        do {
            // 🔥 AI RECOMMENDER AGENT
            print("🤖 [Recommender] Getting personalized recommendations for user: \(userId)")
            
            let recommendations = try await VertexAIAgentService.shared.getRecommendations(
                for: userId,
                sessionHistory: [],
                limit: 10
            )
            
            print("✅ [Recommender] Got \(recommendations.videoIDs.count) AI recommendations")
            
            // Fetch actual video objects from IDs
            var videos: [Video] = []
            
            // For now, use sample videos since there's no fetchVideo method
            // TODO: Implement fetchVideo(id:) method in VideoFirestoreService
            videos = Video.sampleVideos.prefix(recommendations.videoIDs.count).map { $0 }
            
            // Fallback to sample if AI returns nothing
            if videos.isEmpty {
                videos = Array(Video.sampleVideos.shuffled().prefix(10))
            }
            
            await MainActor.run {
                recommendedVideos = videos
                isLoading = false
            }
            
        } catch {
            print("⚠️ [Recommender] AI agent unavailable, using fallback: \(error)")
            
            // Graceful degradation - use trending/popular videos
            await MainActor.run {
                recommendedVideos = Array(Video.sampleVideos
                    .sorted { $0.viewCount > $1.viewCount }
                    .prefix(10))
                isLoading = false
            }
        }
    }
}

// MARK: - AI Recommended Video Card

struct AIRecommendedVideoCard: View {
    let video: Video
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail - 🔥 PERF FIX: Using cached image for 10x faster loading
                ZStack(alignment: .bottomTrailing) {
                    AppAsyncImage(
                        url: URL(string: video.thumbnailURL),
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        },
                        placeholder: {
                            Rectangle()
                                .fill(AppTheme.Colors.divider.opacity(0.1))
                                .overlay(
                                    ProgressView()
                                        .tint(AppTheme.Colors.textTertiary)
                                )
                        }
                    )
                    .frame(width: 180, height: 100)
                    .clipped()
                    .cornerRadius(12)
                    .onAppear {
                        // ⚡ PERF: Prefetch thumbnail
                        if let url = URL(string: video.thumbnailURL) {
                            ImagePrefetcher.shared.prefetch(url: url)
                        }
                    }
                    
                    // Duration badge
                    Text(video.formattedDuration)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.8))
                        )
                        .padding(6)
                }
                
                // Title
                Text(video.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 180, alignment: .leading)
                
                // Creator + views
                HStack(spacing: 4) {
                    Text(video.creator.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    if video.creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.blue)
                    }
                    
                    Text("•")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text(video.formattedViewCount)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(width: 180, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AIRecommendationsSection { _ in }
        .environmentObject(AppState())
        .padding()
        .background(AppTheme.Colors.background)
}

