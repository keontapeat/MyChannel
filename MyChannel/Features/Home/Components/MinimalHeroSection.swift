//
//  MinimalHeroSection.swift
//  MyChannel
//
//  Extracted from HomeView.swift for better code organization
//

import SwiftUI
import AVFoundation
import AVKit
import UIKit

// MARK: - Minimal Hero Section (Pager)
struct MinimalHeroSection: View {
    let featuredContent: [Video]
    @State private var selectedIndex: Int = 0
    let showLiveHeroPreviewInPreviews: Bool
    let onPlayVideo: (Video) -> Void
    let onAddToList: (Video) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appState: AppState
    @State private var showingFeaturedManager = false
    @State private var isUserInteracting = false
    @State private var autoScrollTimer: Timer?
    
    private var isCompact: Bool { horizontalSizeClass == .compact }
    
    private var isAdmin: Bool {
        guard let email = appState.currentUser?.email else { return false }
        return email.lowercased() == "keontapeat@mychannel.live" || 
               email.lowercased() == "keontapeat@gmail.com"
    }

    private func startTimer() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            guard !isUserInteracting, featuredContent.count > 1 else { return }
            let nextIndex = (selectedIndex + 1) % featuredContent.count
            selectedIndex = nextIndex
        }
    }

    private func stopTimer() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
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
                            HStack(spacing: 5) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Edit")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .sheet(isPresented: $showingFeaturedManager) {
                    ThermonuclearFeaturedManager()
                        .environmentObject(appState)
                        .background(
                            UIKitSheetConfigurator(
                                configuration: UIKitSheetConfiguration(
                                    detents: [.large()],
                                    largestUndimmedDetentIdentifier: .large,
                                    prefersGrabberVisible: true,
                                    prefersScrollingExpandsWhenScrolledToEdge: false,
                                    preferredCornerRadius: 28
                                )
                            )
                        )
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
        FeaturedUIKitCarousel(
            videos: featuredContent,
            selectedIndex: $selectedIndex,
            isCompact: isCompact,
            allowLiveInPreview: showLiveHeroPreviewInPreviews,
            onPlayVideo: onPlayVideo,
            onAddToList: onAddToList,
            onUserInteraction: { interacting in
                isUserInteracting = interacting
            }
        )
        .aspectRatio(16/9, contentMode: .fit)
        .background(
            GeometryReader { geo in
                Group {
                    if featuredContent.indices.contains(selectedIndex) {
                        FeaturedHeroPoster(video: featuredContent[selectedIndex])
                            .blur(radius: 40)
                            .opacity(0.45)
                            .scaleEffect(1.2)
                    }
                }
                .animation(.easeInOut(duration: 1.2), value: selectedIndex)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottom) {
            if featuredContent.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<featuredContent.count, id: \.self) { index in
                        Circle()
                            .fill(selectedIndex == index ? Color.white : Color.white.opacity(0.4))
                            .frame(width: 6, height: 6)
                            .animation(.easeInOut(duration: 0.2), value: selectedIndex)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
}


#Preview {
    MinimalHeroSection(
        featuredContent: Video.sampleVideos,
        showLiveHeroPreviewInPreviews: false,
        onPlayVideo: { _ in },
        onAddToList: { _ in }
    )
    .environmentObject(AppState())
}

