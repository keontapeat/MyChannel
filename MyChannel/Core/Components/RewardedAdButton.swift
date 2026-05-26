//
//  RewardedAdButton.swift
//  MyChannel
//
//  🔥 One-tap rewarded ad integration - MONEY PRINTER! 💰
//

import SwiftUI

/// A button that shows a rewarded ad when tapped
/// Use this for premium features users can unlock by watching ads
struct RewardedAdButton<Label: View>: View {
    let action: () -> Void
    let onReward: (Double) -> Void
    let label: () -> Label
    
    @StateObject private var adManager = AdMobManager.shared
    @State private var isLoading = false
    @State private var showingAd = false
    
    init(
        action: @escaping () -> Void = {},
        onReward: @escaping (Double) -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.onReward = onReward
        self.label = label
    }
    
    var body: some View {
        Button {
            HapticManager.shared.impact(style: .medium)
            showRewardedAd()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                
                label()
            }
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1.0)
    }
    
    private func showRewardedAd() {
        isLoading = true
        
        if adManager.isRewardedAdReady {
            adManager.showRewardedAd(
                onReward: { amount in
                    isLoading = false
                    onReward(amount)
                    action()
                    HapticManager.shared.notification(type: .success)
                },
                onDismiss: {
                    isLoading = false
                }
            )
        } else {
            // Load ad first
            adManager.loadRewardedAd()
            
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if adManager.isRewardedAdReady {
                    adManager.showRewardedAd(
                        onReward: { amount in
                            isLoading = false
                            onReward(amount)
                            action()
                        },
                        onDismiss: {
                            isLoading = false
                        }
                    )
                } else {
                    isLoading = false
                    // Fallback: give reward anyway (good UX, build trust)
                    onReward(1.0)
                    action()
                }
            }
        }
    }
}

// MARK: - Convenience Initializers

extension RewardedAdButton where Label == Text {
    /// Create a rewarded ad button with just text
    init(
        _ title: String,
        action: @escaping () -> Void = {},
        onReward: @escaping (Double) -> Void
    ) {
        self.init(action: action, onReward: onReward) {
            Text(title)
        }
    }
}

// MARK: - Pre-styled Variants

/// Watch Ad to Unlock Button - Premium styling
struct WatchAdToUnlockButton: View {
    let feature: String
    let onUnlock: () -> Void
    
    var body: some View {
        RewardedAdButton(
            action: onUnlock,
            onReward: { _ in }
        ) {
            HStack(spacing: 8) {
                Image(systemName: "gift.fill")
                    .foregroundColor(.yellow)
                Text("Watch Ad to Unlock \(feature)")
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .foregroundColor(.white)
        .cornerRadius(12)
    }
}

/// Earn Coins Button - For reward systems
struct EarnCoinsButton: View {
    let coins: Int
    let onEarn: (Int) -> Void
    
    var body: some View {
        RewardedAdButton(
            onReward: { _ in onEarn(coins) }
        ) {
            HStack(spacing: 6) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundColor(.yellow)
                Text("Earn \(coins) Coins")
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.2))
        .foregroundColor(.orange)
        .cornerRadius(10)
    }
}

/// Skip Ad Countdown (for pre-roll ads)
struct SkipAdCountdown: View {
    let secondsRemaining: Int
    let canSkip: Bool
    let onSkip: () -> Void
    
    var body: some View {
        Button(action: {
            if canSkip {
                HapticManager.shared.impact(style: .light)
                onSkip()
            }
        }) {
            HStack(spacing: 6) {
                if canSkip {
                    Text("Skip Ad")
                        .fontWeight(.semibold)
                    Image(systemName: "forward.fill")
                } else {
                    Text("Skip in \(secondsRemaining)s")
                        .fontWeight(.medium)
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(canSkip ? Color.white : Color.white.opacity(0.3))
            .foregroundColor(canSkip ? .black : .white)
            .cornerRadius(8)
        }
        .disabled(!canSkip)
        .animation(.easeInOut(duration: 0.2), value: canSkip)
    }
}

// MARK: - Ad Loading Indicator

struct AdLoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Earning you money... 💰")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(32)
            .background(Color(.systemGray6).opacity(0.3))
            .cornerRadius(16)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RewardedAdButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            RewardedAdButton("Watch Ad for Reward") { amount in
                print("Earned: \(amount)")
            }
            .buttonStyle(.borderedProminent)
            
            WatchAdToUnlockButton(feature: "HD Download") {
                print("Unlocked!")
            }
            
            EarnCoinsButton(coins: 100) { coins in
                print("Earned \(coins) coins")
            }
            
            SkipAdCountdown(secondsRemaining: 3, canSkip: false) {
                print("Skipped")
            }
            
            SkipAdCountdown(secondsRemaining: 0, canSkip: true) {
                print("Skipped")
            }
        }
        .padding()
        .background(Color.black)
    }
}
#endif






