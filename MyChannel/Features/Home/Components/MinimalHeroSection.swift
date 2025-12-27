//
//  MinimalHeroSection.swift
//  MyChannel
//
//  Extracted from HomeView.swift for better code organization
//

import SwiftUI

// MARK: - Minimal Hero Section (Pager)
struct MinimalHeroSection: View {
    let featuredContent: [Video]
    @Binding var selectedIndex: Int
    let showLiveHeroPreviewInPreviews: Bool
    let onPlayVideo: (Video) -> Void
    let onAddToList: (Video) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appState: AppState
    @State private var showingFeaturedManager = false
    
    private var isCompact: Bool { horizontalSizeClass == .compact }
    
    private var isAdmin: Bool {
        guard let email = appState.currentUser?.email else { return false }
        return email.lowercased() == "keontapeat@mychannel.live" || 
               email.lowercased() == "keontapeat@gmail.com"
    }

    var body: some View {
        // Only show section if there are featured videos OR user is admin (to add videos)
        if !featuredContent.isEmpty || isAdmin {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.yellow)
                    Text("FEATURED")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .tracking(1)
                    
                    Spacer()
                    
                    // Quick Edit Button (Admin Only)
                    if isAdmin {
                        Button {
                            HapticManager.shared.impact(style: .light)
                            showingFeaturedManager = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Edit")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.primary.opacity(0.1))
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .sheet(isPresented: $showingFeaturedManager) {
                    ThermonuclearFeaturedManager()
                        .environmentObject(appState)
                }

                // Display: Only show carousel if there are actually featured videos
                if featuredContent.isEmpty {
                    // Empty state for admin
                    if isAdmin {
                        emptyStateView
                    }
                } else {
                    // Show actual featured videos
                    featuredCarouselView
                }
            }
        }
    }
    
    // MARK: - Empty State View
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("No Featured Videos")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Pin up to 3 videos to feature on Home")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Button {
                            HapticManager.shared.impact(style: .medium)
                            showingFeaturedManager = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Add First Video")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.primary)
                            )
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Featured Carousel View
    @ViewBuilder
    private var featuredCarouselView: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(featuredContent.enumerated()), id: \.offset) { index, vid in
                FeaturedHeroCard(
                    video: vid,
                    isCompact: isCompact,
                    showLivePreview: (index == selectedIndex) || (index == 0),
                    allowLiveInPreview: showLiveHeroPreviewInPreviews,
                    onPlay: { onPlayVideo(vid) },
                    onAddToList: { onAddToList(vid) }
                )
                .padding(.horizontal, 20)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Featured Hero Card
struct FeaturedHeroCard: View {
    let video: Video
    let isCompact: Bool
    let showLivePreview: Bool
    let allowLiveInPreview: Bool
    let onPlay: () -> Void
    let onAddToList: () -> Void

    @State private var isPressed = false
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        ZStack {
            // Media layer (poster + optional live autoplay)
            ZStack {
                MultiSourceAsyncImage(
                    urls: video.posterCandidates,
                    content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                    },
                    placeholder: {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemGray6))
                    }
                )

                if showLivePreview && (!isPreview || allowLiveInPreview) {
                    VideoLiveThumbnailView(video: video, cornerRadius: 16)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0.35), .clear, Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )

            // Overlayed content
            VStack(spacing: 12) {
                topBadges
                Spacer()
                bottomContent
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
    
    // MARK: - Top Badges
    @ViewBuilder
    private var topBadges: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: video.category.iconName)
                Text(video.category.displayName)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.35)))

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text(video.formattedDuration)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.35)))
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
    }
    
    // MARK: - Bottom Content
    @ViewBuilder
    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Label(video.creator.displayName, systemImage: "person.crop.circle")
                Label("\(video.formattedViewCount) views", systemImage: "eye")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))

            HStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    onPlay()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Play")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)

                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    onAddToList()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: appState.isVideoInWatchLater(video.id) ? "checkmark" : "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("My List")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.white.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }
}

#Preview {
    MinimalHeroSection(
        featuredContent: Video.sampleVideos,
        selectedIndex: .constant(0),
        showLiveHeroPreviewInPreviews: false,
        onPlayVideo: { _ in },
        onAddToList: { _ in }
    )
    .environmentObject(AppState())
}

