//
//  YouTubeStyleAdOverlay.swift
//  MyChannel
//
//  YouTube-style skippable ad overlay with countdown and skip button
//

import SwiftUI
import AVKit

/// YouTube-style ad overlay that appears on top of the video player
struct YouTubeStyleAdOverlay: View {
    let ad: VideoAd
    let adTimeRemaining: Int
    let canSkip: Bool
    let onSkip: () -> Void
    let onLearnMore: () -> Void
    
    @State private var showSkipAnimation = false
    
    private var timeUntilSkip: Int {
        max(0, ad.skipAfterSeconds - (ad.duration - adTimeRemaining))
    }
    
    private var formattedTimeRemaining: String {
        let minutes = adTimeRemaining / 60
        let seconds = adTimeRemaining % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return String(format: "0:%02d", seconds)
    }
    
    /// Returns nil if the advertiser name is a technical/test label that shouldn't be shown
    private var displayableAdvertiserName: String? {
        guard let advertiser = ad.advertiserName, !advertiser.isEmpty else {
            return nil
        }
        
        // Filter out technical labels from Google Ad Manager test ads
        let technicalPatterns = [
            "external",
            "inline",
            "skippable",
            "single_",
            "preroll",
            "sample",
            "test",
            "linear",
            "ad_tag",
            "vast",
            "vmap"
        ]
        
        let lowercased = advertiser.lowercased()
        for pattern in technicalPatterns {
            if lowercased.contains(pattern) {
                return nil  // Don't show technical names
            }
        }
        
        // Also filter if it looks like a path or URL component
        if advertiser.contains("/") || advertiser.contains("_") {
            return nil
        }
        
        return advertiser
    }
    
    var body: some View {
        ZStack {
            // Full overlay for touch handling
            Color.clear
                .contentShape(Rectangle())
            
            VStack {
                // Top bar: Ad indicator + countdown
                HStack {
                    // Ad indicator (top left)
                    HStack(spacing: 6) {
                        Text("Ad")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow)
                            .cornerRadius(3)
                        
                        // Ad countdown
                        Text(formattedTimeRemaining)
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
                    
                    Spacer()
                    
                    // Advertiser name (top right) - only show if it's a real brand name
                    if let advertiser = displayableAdvertiserName {
                        Text(advertiser)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.5))
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                Spacer()
                
                // Bottom bar: Learn more + Skip button
                HStack(alignment: .bottom) {
                    // Learn more button (bottom left)
                    Button(action: onLearnMore) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                            Text("Learn more")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(AdScaleButtonStyle())
                    
                    Spacer()
                    
                    // Skip button (bottom right) - YouTube style
                    skipButtonView
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
    
    @ViewBuilder
    private var skipButtonView: some View {
        if canSkip {
            // Skip button (enabled)
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                onSkip()
            }) {
                HStack(spacing: 8) {
                    Text("Skip Ad")
                        .font(.system(size: 14, weight: .bold))
                    
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(AdScaleButtonStyle())
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .opacity
            ))
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showSkipAnimation = true
                }
                HapticManager.shared.impact(style: .light)
            }
        } else if ad.isSkippable && timeUntilSkip > 0 {
            // Skip countdown (waiting)
            HStack(spacing: 8) {
                Text("Skip ad in")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                // Countdown circle
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(timeUntilSkip) / CGFloat(ad.skipAfterSeconds))
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timeUntilSkip)
                    
                    Text("\(timeUntilSkip)")
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.7))
            )
        }
    }
}

/// Full-screen ad player view with overlay
struct YouTubeStyleAdPlayerView: View {
    let ad: VideoAd
    @ObservedObject var adManager: GoogleIMAAdManager
    let onComplete: () -> Void
    let onSkip: () -> Void
    let onLearnMore: (URL) -> Void
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()
            
            // Ad video player
            if let player = adManager.adPlayer {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .disabled(true)  // Prevent interaction with video controls
                    .onAppear {
                        print("🎥 [YouTubeStyleAdPlayerView] VideoPlayer appeared, rate: \(player.rate)")
                        // Ensure video is playing when view appears
                        if player.rate == 0 {
                            player.play()
                            print("▶️ [YouTubeStyleAdPlayerView] Called play() on player")
                        }
                    }
            } else {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Loading ad...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .onAppear {
                    print("⏳ [YouTubeStyleAdPlayerView] Loading state shown (adPlayer is nil)")
                }
            }
            
            // Ad overlay
            if let currentAd = adManager.currentAd {
                YouTubeStyleAdOverlay(
                    ad: currentAd,
                    adTimeRemaining: adManager.adTimeRemaining,
                    canSkip: adManager.canSkip,
                    onSkip: {
                        adManager.skipAd()
                        onSkip()
                    },
                    onLearnMore: {
                        if let url = URL(string: currentAd.clickURL), !currentAd.clickURL.isEmpty {
                            adManager.clickAd()
                            onLearnMore(url)
                        }
                    }
                )
            }
        }
        .onAppear {
            print("🎬 [YouTubeStyleAdPlayerView] View appeared - ad: \(ad.mediaURL)")
            
            // Setup callbacks
            adManager.onAdComplete = {
                print("✅ [YouTubeStyleAdPlayerView] Ad complete callback fired")
                onComplete()
            }
            adManager.onAdSkipped = {
                print("⏭️ [YouTubeStyleAdPlayerView] Ad skipped callback fired")
                onSkip()
            }
            adManager.onAdClicked = { url in
                print("👆 [YouTubeStyleAdPlayerView] Ad clicked: \(url)")
                openURL(url)
            }
            adManager.onAdError = { error in
                print("❌ [YouTubeStyleAdPlayerView] Ad error: \(error)")
            }
            
            // Play the ad
            print("▶️ [YouTubeStyleAdPlayerView] Calling playAd()")
            adManager.playAd(ad)
        }
        .onDisappear {
            adManager.cleanup()
        }
    }
}

/// Compact ad overlay for inline video players
struct CompactAdOverlay: View {
    let ad: VideoAd
    let timeRemaining: Int
    let canSkip: Bool
    let onSkip: () -> Void
    let onLearnMore: () -> Void
    
    private var timeUntilSkip: Int {
        max(0, ad.skipAfterSeconds - (ad.duration - timeRemaining))
    }
    
    var body: some View {
        VStack {
            // Top: Ad badge
            HStack {
                Text("Ad • \(timeRemaining)s")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            Spacer()
            
            // Bottom: Buttons
            HStack {
                // Learn more (compact)
                Button(action: onLearnMore) {
                    Text("Learn more")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                }
                .buttonStyle(AdScaleButtonStyle())
                
                Spacer()
                
                // Skip button
                if canSkip {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .cornerRadius(4)
                    }
                    .buttonStyle(AdScaleButtonStyle())
                } else if ad.isSkippable && timeUntilSkip > 0 {
                    Text("\(timeUntilSkip)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.black.opacity(0.7)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Scale Button Style (Ad-specific to avoid collision)
struct AdScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Previews
#Preview("YouTube-Style Ad Overlay") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        // Simulated video
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .aspectRatio(16/9, contentMode: .fit)
        
        YouTubeStyleAdOverlay(
            ad: VideoAd.sample,
            adTimeRemaining: 12,
            canSkip: false,
            onSkip: {},
            onLearnMore: {}
        )
    }
}

#Preview("Skip Available") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .aspectRatio(16/9, contentMode: .fit)
        
        YouTubeStyleAdOverlay(
            ad: VideoAd.sample,
            adTimeRemaining: 8,
            canSkip: true,
            onSkip: {},
            onLearnMore: {}
        )
    }
}

#Preview("Compact Overlay") {
    ZStack {
        Color.black
        
        CompactAdOverlay(
            ad: VideoAd.sample,
            timeRemaining: 10,
            canSkip: true,
            onSkip: {},
            onLearnMore: {}
        )
    }
    .frame(height: 250)
}



