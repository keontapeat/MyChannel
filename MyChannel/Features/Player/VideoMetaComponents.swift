// ⚡ PERFORMANCE: Extracted from VideoDetailMetaView.swift — independent compilation unit.
// Like/dislike pill, action pills, AI sheet, Remix sheet, SmartTag, AnimatedViewCount
// compile in parallel with the 821-line main VideoDetailMetaView struct.
import SwiftUI

// MARK: - 🔥 YOUTUBE 2024 EXACT: Combined Like/Dislike Pill
/// Exact replica of YouTube's combined like/dislike button with separator
struct YouTubeLikeDislikePill: View {
    let likeCount: Int
    let isLiked: Bool
    let isDisliked: Bool
    var likeScale: CGFloat = 1.0
    let onLike: () -> Void
    let onDislike: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Like Button
            Button(action: onLike) {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isLiked ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                    
                    Text(formatCount(likeCount))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .scaleEffect(likeScale)
            }
            .buttonStyle(PillPressedButtonStyle())
            .accessibilityLabel(isLiked ? "Unlike" : "Like")
            .accessibilityValue("\(likeCount) likes")
            
            // Separator Line (YouTube exact style)
            Rectangle()
                .fill(AppTheme.Colors.textSecondary.opacity(0.3))
                .frame(width: 1, height: 18)
            
            // Dislike Button
            Button(action: onDislike) {
                Image(systemName: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDisliked ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(PillPressedButtonStyle())
            .accessibilityLabel(isDisliked ? "Remove dislike" : "Dislike")
        }
        .background(
            Capsule()
                .fill(AppTheme.Colors.surface)
        )
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

// MARK: - 🔥 FIX: Custom ButtonStyle that doesn't block ScrollView gestures
/// Uses configuration.isPressed instead of DragGesture to detect pressed state
struct PillPressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - 🔥 YOUTUBE 2024 EXACT: Action Pill Button
/// Simple pill button matching YouTube's exact style
/// 🔥 FIX: Uses PillPressedButtonStyle instead of DragGesture to allow ScrollView scrolling
struct YouTubeActionPill: View {
    let icon: String
    let title: String
    var iconColor: Color? = nil
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(iconColor ?? (isActive ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary))
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.surface)
            )
        }
        .buttonStyle(PillPressedButtonStyle())
        .accessibilityLabel("\(title) button")
    }
}

// MARK: - 🔥 YOUTUBE PARITY: Ask AI Sheet (Gemini-style)
struct AskAISheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var question: String = ""
    @State private var isLoading = false
    @State private var response: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // AI Icon
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 24)
                
                Text("Ask about this video")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Get AI-powered answers about \"\(video.title)\"")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // Question Input
                TextField("Ask a question...", text: $question, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .lineLimit(3...6)
                
                // Suggested Questions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["Summarize this video", "What are the key points?", "Who is the speaker?"], id: \.self) { suggestion in
                                Button(action: { question = suggestion }) {
                                    Text(suggestion)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.Colors.surface)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
                
                // Ask Button
                Button(action: {
                    isLoading = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        isLoading = false
                        response = "This is an AI-generated response about the video."
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                            Text("Ask AI")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(24)
                }
                .disabled(question.isEmpty || isLoading)
                .opacity(question.isEmpty ? 0.5 : 1.0)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(AppTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 🔥 YOUTUBE PARITY: Remix Sheet
struct RemixSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("Remix this video")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Create your own version using this video")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.top, 32)
                
                // Remix Options
                VStack(spacing: 12) {
                    RemixOptionRow(
                        icon: "music.note",
                        title: "Use this sound",
                        subtitle: "Create a video with the same audio"
                    )
                    
                    RemixOptionRow(
                        icon: "scissors",
                        title: "Cut",
                        subtitle: "Trim this video into a Short"
                    )
                    
                    RemixOptionRow(
                        icon: "square.on.square",
                        title: "Green Screen",
                        subtitle: "Use this video as a background"
                    )
                    
                    RemixOptionRow(
                        icon: "rectangle.on.rectangle",
                        title: "Collab",
                        subtitle: "Create a side-by-side video"
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(AppTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct RemixOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 44, height: 44)
                .background(AppTheme.Colors.surface)
                .cornerRadius(22)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
    }
}

// MARK: - 🔥 YOUTUBE 2024 STYLE: Pill-Shaped Action Button Component (Legacy)
/// Compact horizontal pill button matching YouTube's 2024 Material You design
/// - Icon + text side-by-side in a rounded pill shape
/// - Much smaller footprint than vertical stacked buttons
/// - Sleek, minimal, professional appearance
struct VideoMetaActionButton: View {
    let icon: String
    let title: String
    var isActive: Bool = false
    var activeColor: Color = AppTheme.Colors.primary
    var hasSpecialEffect: Bool = false
    var isPremium: Bool = false
    var scale: CGFloat = 1.0
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isActive ? activeColor : AppTheme.Colors.textSecondary)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                
                // Title
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isActive ? activeColor : AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                
                // Premium indicator (inline)
                if isPremium {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? activeColor.opacity(0.12) : AppTheme.Colors.surface.opacity(0.9))
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? activeColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect((isPressed ? 0.95 : 1.0) * pulseScale * scale)
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
            if hasSpecialEffect {
                startPulseAnimation()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) button")
        .accessibilityHint(isActive ? "Currently active" : "Tap to activate")
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.02
        }
    }
}

// MARK: - 🔥 YOUTUBE 2024 STYLE: Minimal Tag Pill
struct SmartTagView: View {
    let tag: String
    let index: Int
    
    var body: some View {
        Text("#\(tag)")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AppTheme.Colors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.surface.opacity(0.9))
            )
            .accessibilityLabel("Tag: \(tag)")
    }
}

// MARK: - 🔥 PREMIUM: Animated View Count Text
struct AnimatedViewCountText: View {
    let viewCount: Int
    
    @State private var displayedCount: Int = 0
    @State private var hasAnimated = false
    
    var body: some View {
        Text(formatCount(displayedCount))
            .font(.system(size: 13, weight: .regular))
            .contentTransition(.numericText())
            .onAppear {
                guard !hasAnimated else { return }
                hasAnimated = true
                animateCount()
            }
            .onChange(of: viewCount) { newValue in
                // Smoothly animate to new value
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    displayedCount = newValue
                }
            }
    }
    
    private func animateCount() {
        // 🔥 PREMIUM: Smooth count-up animation — single Task replaces 21 simultaneous DispatchQueue timers
        let steps = min(viewCount, 20)
        guard steps > 0 else {
            displayedCount = viewCount
            return
        }
        let target = viewCount
        let stepNanos = UInt64(500_000_000 / steps) // 0.5 s total
        Task { @MainActor in
            for step in 0...steps {
                let progress = Double(step) / Double(steps)
                let easedProgress = 1 - pow(1 - progress, 3) // Cubic ease-out
                withAnimation(.spring(response: 0.15, dampingFraction: 0.9)) {
                    displayedCount = Int(Double(target) * easedProgress)
                }
                if step < steps {
                    try? await Task.sleep(nanoseconds: stepNanos)
                }
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

// MARK: - Preview
#Preview {
    NavigationView {
        VideoDetailMetaView(
            video: Video.sampleVideos[0],
            isSubscribed: .constant(false),
            isWatchLater: .constant(false),
            isLiked: .constant(false),
            isDisliked: .constant(false),
            expandedDescription: .constant(false),
            onShare: { print("Share tapped") },
            onMore: { print("More tapped") },
            onComment: { print("Comment tapped") },
            relatedVideos: [],
            onSelectRelated: nil
        )
        .preferredColorScheme(.light)
    }
}