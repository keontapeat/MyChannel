//
//  FlicksPlayerOverlay.swift
//  MyChannel
//
//  Minimal + classic engagement overlays extracted from ProfessionalVideoPlayer.
//

import SwiftUI

struct FlicksPlayerOverlay: View {
    typealias OverlayStyle = ProfessionalVideoPlayer.OverlayStyle

    let style: OverlayStyle
    let video: Video
    let isLiked: Bool
    let isFollowing: Bool
    let isMuted: Bool
    let isPlaying: Bool
    let subscriberCount: Int
    let currentProgress: Double
    let bufferedProgress: Double
    let hasAppeared: Bool
    let discRotation: Double
    @Binding var profileRingPhase: CGFloat
    @Binding var actionButtonsScale: [Int: CGFloat]

    let reduceMotion: Bool
    let onLike: () -> Void
    let onFollow: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    let onProfileTap: () -> Void
    let onToggleMute: () -> Void
    let onRevealOverlay: () -> Void
    let onSpawnLikeParticles: () -> Void

    var body: some View {
        Group {
            if style == .minimal {
                minimalOverlay
            } else {
                classicOverlay
            }
        }
    }

    private var minimalOverlay: some View {
        GeometryReader { proxy in
            let safeInsets = proxy.safeAreaInsets
            VStack(spacing: 0) {
                progressIndicator
                    .padding(.top, max(12, safeInsets.top + 8))
                    .padding(.horizontal, 28)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : -20)

                Spacer()

                bottomOverlay(insets: safeInsets)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var progressIndicator: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.12))
                    .frame(height: 3)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .white.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, CGFloat(bufferedProgress) * proxy.size.width), height: 3)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white)
                        .frame(width: max(6, CGFloat(currentProgress) * proxy.size.width), height: 3)
                        .shadow(color: .white.opacity(0.5), radius: 4, x: 0, y: 0)

                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: .white.opacity(0.6), radius: 4)
                        .offset(x: max(0, CGFloat(currentProgress) * proxy.size.width - 4))
                        .opacity(currentProgress > 0.01 ? 1 : 0)
                }
            }
        }
        .frame(height: 14)
    }

    private func bottomOverlay(insets: EdgeInsets) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.05),
                    .black.opacity(0.2),
                    .black.opacity(0.5),
                    .black.opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300 + insets.bottom)
            .allowsHitTesting(false)

            HStack(alignment: .bottom, spacing: 16) {
                detailCard
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(x: hasAppeared ? 0 : -30)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: hasAppeared)
                    .padding(.leading, max(16, insets.leading + 14))

                actionColumn
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(x: hasAppeared ? 0 : 30)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
                    .padding(.trailing, max(16, insets.trailing + 14))
            }
            .padding(.bottom, max(24, insets.bottom + 18))
        }
        .frame(maxWidth: .infinity)
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Button(action: {
                    onProfileTap()
                    onRevealOverlay()
                    HapticManager.shared.impact(style: .light)
                }) {
                    ZStack {
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        AppTheme.Colors.primary,
                                        AppTheme.Colors.primary.opacity(0.6),
                                        Color.white.opacity(0.8),
                                        AppTheme.Colors.primary.opacity(0.6),
                                        AppTheme.Colors.primary
                                    ],
                                    center: .center,
                                    startAngle: .degrees(profileRingPhase),
                                    endAngle: .degrees(profileRingPhase + 360)
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: 52, height: 52)

                        AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.white.opacity(0.2))
                        }
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                    }
                    .onAppear {
                        if !reduceMotion {
                            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                                profileRingPhase = 360
                            }
                        }
                    }
                }
                .buttonStyle(PremiumScaleButtonStyle())

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text("@\(video.creator.username)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if video.creator.shouldShowVerificationBadge {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.verificationBlue, AppTheme.Colors.verificationBlue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: AppTheme.Colors.verificationBlue.opacity(0.5), radius: 4)
                        }
                    }
                    FlicksAnimatedCount(value: subscriberCount, suffix: " subscribers")
                }

                Spacer()

                Button(action: {
                    onFollow()
                    onRevealOverlay()
                    HapticManager.shared.impact(style: .medium)
                }) {
                    HStack(spacing: 4) {
                        if isFollowing {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        Group {
                            if isFollowing {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            } else {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.Colors.primary, AppTheme.Colors.primaryDark],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                        }
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(PremiumScaleButtonStyle())
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFollowing)
            }

            Text(video.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

            if !topTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(topTags.enumerated()), id: \.element) { index, tag in
                            Text("#\(tag)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.18),
                                                    Color.white.opacity(0.08)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                        )
                                )
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(x: hasAppeared ? 0 : 20)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.3 + Double(index) * 0.05), value: hasAppeared)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 22, height: 22)

                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                }
                .rotationEffect(.degrees(isPlaying && !isMuted ? discRotation : 0))

                Text("Original Audio")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                Text("·")
                    .foregroundColor(.white.opacity(0.5))

                Text(video.creator.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionColumn: some View {
        VStack(spacing: 20) {
            premiumMetricButton(
                index: 0,
                systemName: isLiked ? "heart.fill" : "heart",
                value: displayedLikeCount,
                iconTint: isLiked ? .red : .white,
                showGlow: isLiked,
                glowColor: .red
            ) {
                onLike()
                onSpawnLikeParticles()
                HapticManager.shared.notification(type: isLiked ? .warning : .success)
                onRevealOverlay()
            }

            premiumMetricButton(
                index: 1,
                systemName: "bubble.right.fill",
                value: video.commentCount,
                iconTint: .white
            ) {
                onComment()
                HapticManager.shared.impact(style: .light)
                onRevealOverlay()
            }

            premiumMetricButton(
                index: 2,
                systemName: "arrowshape.turn.up.right.fill",
                label: "Share",
                iconTint: .white
            ) {
                onShare()
                HapticManager.shared.impact(style: .light)
                onRevealOverlay()
            }

            premiumMetricButton(
                index: 3,
                systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: isMuted ? "Sound" : "Mute",
                iconTint: isMuted ? .white.opacity(0.7) : .white,
                showGlow: !isMuted,
                glowColor: AppTheme.Colors.accent
            ) {
                onToggleMute()
                HapticManager.shared.impact(style: .rigid)
                onRevealOverlay()
            }

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.black, Color.black.opacity(0.8), Color.black],
                            center: .center,
                            startRadius: 0,
                            endRadius: 24
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    )

                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle().fill(Color.white.opacity(0.2))
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .fill(Color.black)
                        .frame(width: 8, height: 8)
                )
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                .white.opacity(0.6),
                                AppTheme.Colors.primary.opacity(0.8),
                                .white.opacity(0.3),
                                AppTheme.Colors.primary.opacity(0.6),
                                .white.opacity(0.6)
                            ],
                            center: .center
                        ),
                        lineWidth: 2
                    )
            )
            .rotationEffect(.degrees(isPlaying ? discRotation : 0))
            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
            .opacity(hasAppeared ? 1 : 0)
            .scaleEffect(hasAppeared ? 1 : 0.5)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5), value: hasAppeared)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
    }

    @ViewBuilder
    private func premiumMetricButton(
        index: Int,
        systemName: String,
        value: Int? = nil,
        label: String? = nil,
        iconTint: Color = .white,
        showGlow: Bool = false,
        glowColor: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if showGlow {
                        Circle()
                            .fill(glowColor.opacity(0.3))
                            .frame(width: 52, height: 52)
                            .blur(radius: 8)
                    }

                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Circle()
                                .stroke(
                                    showGlow
                                        ? glowColor.opacity(0.5)
                                        : Color.white.opacity(0.15),
                                    lineWidth: 1
                                )
                        )

                    Image(systemName: systemName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(iconTint)
                        .shadow(color: showGlow ? glowColor.opacity(0.5) : .clear, radius: 4)
                }
                .scaleEffect(actionButtonsScale[index] ?? 1.0)

                if let value = value {
                    FlicksAnimatedCount(value: value, font: .system(size: 12, weight: .bold))
                } else if let label = label {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(PremiumActionButtonStyle(index: index, scales: $actionButtonsScale))
        .opacity(hasAppeared ? 1 : 0)
        .offset(x: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.25 + Double(index) * 0.06), value: hasAppeared)
    }

    private var classicOverlay: some View {
        VStack {
            Spacer()
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(video.title).font(.headline.weight(.semibold)).foregroundStyle(.white).lineLimit(2)
                    Text("@\(video.creator.username)").font(.subheadline).foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }

    private var displayedLikeCount: Int {
        max(0, video.likeCount + (isLiked ? 1 : 0))
    }

    private var topTags: [String] {
        Array(video.tags.prefix(3))
    }
}

/// Premium scale button style with spring animation
struct PremiumScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Premium action button style with individual scale tracking
struct PremiumActionButtonStyle: ButtonStyle {
    let index: Int
    @Binding var scales: [Int: CGFloat]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                scales[index] = pressed ? 0.85 : 1.0
            }
    }
}

/// Animated count display for Flicks metrics
struct FlicksAnimatedCount: View {
    let value: Int
    var suffix: String = ""
    var font: Font = .system(size: 12, weight: .medium)

    @State private var displayedValue: Int = 0
    @State private var hasAnimated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(formatCount(displayedValue) + suffix)
            .font(font)
            .foregroundColor(.white.opacity(0.9))
            .contentTransition(.numericText())
            .onAppear {
                guard !hasAnimated else { return }
                hasAnimated = true
                if reduceMotion {
                    displayedValue = value
                } else {
                    animateCount()
                }
            }
            .onChange(of: value) { newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    displayedValue = newValue
                }
            }
    }

    private func animateCount() {
        let steps = min(value, 15)
        guard steps > 0 else {
            displayedValue = value
            return
        }
        let target = value
        let stepNanos = UInt64(400_000_000 / steps)
        Task { @MainActor in
            for step in 0...steps {
                let progress = Double(step) / Double(steps)
                let easedProgress = 1 - pow(1 - progress, 3)
                withAnimation(.spring(response: 0.12, dampingFraction: 0.9)) {
                    displayedValue = Int(Double(target) * easedProgress)
                }
                if step < steps { try? await Task.sleep(nanoseconds: stepNanos) }
            }
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
