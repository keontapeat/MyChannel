// ⚡ PERFORMANCE: Extracted from AwardsComponents.swift — independent compilation unit.
// WinnerSpotlightCard + animation modifiers compile in parallel.
import SwiftUI

struct WinnerSpotlightCard: View {
    let winner: LiveStreamerAwardsSystem.Winner
    let year: Int
    let onPlayVideo: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Video thumbnail
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 180)
                
                // Play button overlay
                Button(action: onPlayVideo) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Winner info
            VStack(spacing: 12) {
                // Trophy with year
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.awardGold, Color.awardGold.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                    
                    Text("\(year)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.awardGold)
                }
                
                // Winner name
                Text(winner.streamer.username)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                // Category
                Text(winner.category.rawValue)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(20)
        }
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
    }
}

// MARK: - Staggered Reveal Animation

struct StaggeredRevealModifier: ViewModifier {
    let index: Int
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func staggeredReveal(index: Int, delay: Double = 0.1) -> some View {
        modifier(StaggeredRevealModifier(index: index, delay: delay))
    }
}

// MARK: - Press Scale Animation

struct PressScaleModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    func pressScale() -> some View {
        modifier(PressScaleModifier())
    }
}

// MARK: - Shimmer Effect

extension View {
}

// MARK: - Live Ceremony Stream View

struct LiveCeremonyStreamView: View {
    let streamURL: String
    let onDismiss: () -> Void
    
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @State private var showChat = true
    @State private var reactions: [String] = []
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Video player area
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fit)
                    
                    // Placeholder for video player
                    VStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        Text("Live Ceremony")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    // Controls overlay
                    VStack {
                        HStack {
                            // Live indicator
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("LIVE")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(12)
                            
                            Spacer()
                            
                            // Minimize to native PiP button
                            Button(action: {
                                globalPlayer.startPiP()
                                onDismiss()
                            }) {
                                Image(systemName: "pip.enter")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Minimize to mini player")
                            
                            // Close button
                            Button(action: onDismiss) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                        }
                        .padding()
                        
                        Spacer()
                    }
                }
                
                // Chat and reactions
                if showChat {
                    chatOverlay
                }
            }
            
            // Floating reactions
            ForEach(reactions.indices, id: \.self) { index in
                Text(reactions[index])
                    .font(.system(size: 40))
                    .offset(y: -200)
                    .opacity(0)
                    .animation(.easeOut(duration: 2.0), value: reactions)
            }
        }
        .accessibilityLabel("Live ceremony stream")
    }
    
    private var chatOverlay: some View {
        VStack(spacing: 0) {
            // Chat header
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16))
                Text("Live Chat")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Button(action: { showChat.toggle() }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                }
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.8))
            
            // Chat messages
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        chatMessage
                    }
                }
                .padding()
            }
            .frame(height: 200)
            .background(Color.black.opacity(0.6))
            
            // Reaction buttons
            HStack(spacing: 16) {
                ForEach(["🎉", "👏", "❤️", "🔥", "🏆"], id: \.self) { emoji in
                    Button(action: {
                        reactions.append(emoji)
                    }) {
                        Text(emoji)
                            .font(.system(size: 28))
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
        }
    }
    
    private var chatMessage: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.gray)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Username")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("This is amazing! 🎉")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}

// MARK: - Supporting Models

struct AwardNominee: Identifiable {
    let id: String
    let streamerName: String
    let categoryName: String
    let voteCount: Int
    let avgViewers: String
    let hoursStreamed: String
    let subscribers: String
}

// MARK: - Previews

#Preview("Ceremony Countdown") {
    CeremonyCountdownHero(
        ceremonyDate: Date().addingTimeInterval(86400 * 30),
        isLive: false,
        isVotingOpen: true,
        onWatchLive: {},
        onVote: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Nominee Card") {
    NomineeCard(
        nominee: AwardNominee(
            id: "1",
            streamerName: "StreamerPro",
            categoryName: "Best Gaming Streamer",
            voteCount: 1250,
            avgViewers: "5.2K",
            hoursStreamed: "342",
            subscribers: "2.1K"
        ),
        isVoted: false,
        onVote: {}
    )
    .padding()
    .background(Color.black)
}

#Preview("Premium Category Card") {
    PremiumCategoryCard(
        category: LiveStreamerAwardsSystem.AwardCategory.gamingStreamer,
        isExpanded: false,
        onTap: {}
    )
    .padding()
    .frame(width: 180)
}

#Preview("Winner Spotlight") {
    WinnerSpotlightCard(
        winner: LiveStreamerAwardsSystem.Winner(
            category: .gamingStreamer,
            streamer: User.sampleUsers[0],
            acceptanceSpeech: "Thank you everyone!",
            clipURL: nil
        ),
        year: 2024,
        onPlayVideo: {}
    )
    .frame(width: 280)
    .padding()
}

#Preview("Voting Progress") {
    VStack(spacing: 16) {
        ForEach(0..<3, id: \.self) { index in
            VotingProgressBar(
                nominee: AwardNominee(
                    id: "\(index)",
                    streamerName: "Nominee \(index + 1)",
                    categoryName: "Best Gaming",
                    voteCount: [1500, 1200, 800][index],
                    avgViewers: "5.2K",
                    hoursStreamed: "342",
                    subscribers: "2.1K"
                ),
                totalVotes: 3500,
                isLeading: index == 0
            )
        }
    }
    .padding()
    .background(Color.black)
}

