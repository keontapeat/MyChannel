//
//  DownloadButtonView.swift
//  MyChannel
//
//  🔥 YOUTUBE 2024 STYLE: Pill-shaped download button with proper states
//  💰 Now with Watch Ad to Download option!
//

import SwiftUI

struct DownloadButtonView: View {
    let video: Video
    let action: () -> Void
    
    @StateObject private var premiumService = PremiumService.shared
    @StateObject private var offlineService = OfflineDownloadService.shared
    @StateObject private var adManager = AdMobManager.shared
    
    @State private var showingAdOption = false
    @State private var isWatchingAd = false
    @State private var adUnlockedDownload = false  // Temporary unlock via ad
    
    private var downloadState: DownloadState {
        // Check if downloading
        if let download = offlineService.downloads.first(where: { $0.videoId == video.id && $0.status == .downloading }) {
            return .downloading(progress: download.progress)
        }
        
        // Check if downloaded
        if offlineService.isVideoAvailableOffline(video.id) {
            if let download = offlineService.downloads.first(where: { $0.videoId == video.id && $0.status == .completed }) {
                // Check if expired (48 hours like YouTube)
                let expirationDate = download.expiresAt
                let now = Date()
                let timeRemaining = expirationDate.timeIntervalSince(now)
                
                if timeRemaining <= 0 {
                    return .expired
                } else {
                    return .downloaded(expiresAt: expirationDate)
                }
            }
        }
        
        // Check if premium OR ad-unlocked
        if premiumService.isPremium || adUnlockedDownload {
            return .available
        } else {
            return .premiumRequired
        }
    }
    
    enum DownloadState: Equatable {
        case available
        case downloading(progress: Double)
        case downloaded(expiresAt: Date)
        case expired
        case premiumRequired
        
        static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
            switch (lhs, rhs) {
            case (.available, .available):
                return true
            case (.downloading(let lhsProgress), .downloading(let rhsProgress)):
                return lhsProgress == rhsProgress
            case (.downloaded(let lhsDate), .downloaded(let rhsDate)):
                return lhsDate == rhsDate
            case (.expired, .expired):
                return true
            case (.premiumRequired, .premiumRequired):
                return true
            default:
                return false
            }
        }
    }
    
    @State private var isPressed: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            // 💰 Show ad option for non-premium users
            if downloadState == .premiumRequired {
                showingAdOption = true
            } else {
                action()
            }
        }) {
            HStack(spacing: 6) {
                // Icon with inline progress
                ZStack {
                    downloadIcon
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                    
                    // Progress ring for downloading state
                    if case .downloading(let progress) = downloadState {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(iconColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 18, height: 18)
                    }
                }
                
                // Title with progress percentage if downloading
                if case .downloading(let progress) = downloadState {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(iconColor)
                        .lineLimit(1)
                } else {
                    Text(downloadTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(iconColor)
                        .lineLimit(1)
                }
                
                // Premium/Ad indicator
                if downloadState == .premiumRequired {
                    // 💰 Show play icon to indicate ad option
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
                
                // Loading indicator for ad
                if isWatchingAd {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .green))
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(backgroundFill)
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? iconColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect((isPressed ? 0.95 : 1.0) * pulseScale)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: pulseScale)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onAppear {
            if case .downloading = downloadState {
                startPulseAnimation()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(downloadTitle) button")
        .confirmationDialog(
            "Download Video",
            isPresented: $showingAdOption,
            titleVisibility: .visible
        ) {
            Button("Watch Ad to Download Free") {
                watchAdToUnlock()
            }
            
            Button("Get Premium - Unlimited Downloads") {
                // Navigate to premium
                premiumService.showPremiumUpsell = true
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Watch a short ad to unlock this download, or upgrade to Premium for unlimited downloads!")
        }
    }
    
    // MARK: - 💰 Watch Ad to Unlock Download
    
    private func watchAdToUnlock() {
        isWatchingAd = true
        HapticManager.shared.impact(style: .medium)
        
        // Track the ad impression
        AdRevenueTracker.shared.trackImpression(
            adType: .rewarded,
            videoId: video.id,
            creatorId: video.creator.id
        )
        
        if adManager.isRewardedAdReady {
            adManager.showRewardedAd(
                onReward: { _ in
                    // Ad completed - unlock download!
                    adUnlockedDownload = true
                    isWatchingAd = false
                    
                    // Track rewarded completion
                    AdRevenueTracker.shared.trackRewardedComplete(
                        videoId: video.id,
                        creatorId: video.creator.id
                    )
                    
                    HapticManager.shared.notification(type: .success)
                    
                    // Auto-start download
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        action()
                    }
                },
                onDismiss: {
                    isWatchingAd = false
                }
            )
        } else {
            // Ad not ready - give free unlock (good UX)
            print("⚠️ [Download] Ad not ready, granting free unlock")
            adUnlockedDownload = true
            isWatchingAd = false
            action()
        }
    }
    
    private var isActive: Bool {
        switch downloadState {
        case .downloaded, .downloading:
            return true
        default:
            return false
        }
    }
    
    private var backgroundFill: Color {
        switch downloadState {
        case .available:
            return AppTheme.Colors.surface.opacity(0.9)
        case .downloading:
            return Color.blue.opacity(0.12)
        case .downloaded:
            return Color.green.opacity(0.12)
        case .expired:
            return Color.orange.opacity(0.12)
        case .premiumRequired:
            return AppTheme.Colors.surface.opacity(0.9)
        }
    }
    
    private var iconColor: Color {
        switch downloadState {
        case .available:
            return AppTheme.Colors.textSecondary
        case .downloading:
            return .blue
        case .downloaded:
            return .green
        case .expired:
            return .orange
        case .premiumRequired:
            return AppTheme.Colors.textSecondary
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.02
        }
    }
    
    @ViewBuilder
    private var downloadIcon: some View {
        switch downloadState {
        case .available:
            Image(systemName: "arrow.down.to.line")
        case .downloading:
            Image(systemName: "arrow.down.circle.fill")
        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
        case .expired:
            Image(systemName: "arrow.clockwise")
        case .premiumRequired:
            Image(systemName: "arrow.down.to.line")
        }
    }
    
    private var downloadTitle: String {
        switch downloadState {
        case .available:
            return "Download"
        case .downloading:
            return "Downloading"
        case .downloaded:
            return "Saved"
        case .expired:
            return "Expired"
        case .premiumRequired:
            return "Download"
        }
    }
}

