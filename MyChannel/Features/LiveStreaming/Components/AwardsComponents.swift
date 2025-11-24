//
//  AwardsComponents.swift
//  MyChannel
//
//  Premium Awards Show Components
//  Oscars x Grammys x BET x Apple x Netflix Fusion
//

import SwiftUI

// MARK: - Awards Color Palette

extension Color {
    static let awardGold = Color(red: 212/255, green: 175/255, blue: 55/255)
    static let awardSilver = Color(red: 192/255, green: 192/255, blue: 192/255)
    static let awardBronze = Color(red: 205/255, green: 127/255, blue: 50/255)
    static let ceremonyRed = Color(red: 139/255, green: 0/255, blue: 0/255)
    static let prestigeBlack = Color(red: 18/255, green: 18/255, blue: 18/255)
    
    // Dark mode adaptive colors
    static let awardSurface = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ?
            UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0) :
            UIColor(red: 249/255, green: 249/255, blue: 249/255, alpha: 1.0)
    })
    
    static let awardBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ?
            UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 1.0) :
            UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)
    })
}

// MARK: - Ceremony Countdown Hero

struct CeremonyCountdownHero: View {
    let ceremonyDate: Date
    let isLive: Bool
    let isVotingOpen: Bool
    let onWatchLive: () -> Void
    let onVote: () -> Void
    
    @State private var timeRemaining: TimeInterval = 0
    @State private var starlightOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Cinematic gradient backdrop (Oscars-inspired)
            LinearGradient(
                colors: [
                    Color.awardGold,
                    Color.awardGold.opacity(0.8),
                    Color.prestigeBlack
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .accessibilityHidden(true)
            
            // Subtle starlight particles
            GeometryReader { geometry in
                ForEach(0..<20, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 3, height: 3)
                        .offset(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: starlightOffset + CGFloat(index * 30)
                        )
                        .opacity(Double.random(in: 0.2...0.6))
                }
            }
            
            // Content
            VStack(spacing: 24) {
                // Live indicator or countdown
                if isLive {
                    liveIndicator
                } else {
                    countdownTimer
                }
                
                // Title
                Text("Streamer Awards")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Season 2025")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .accessibilityLabel("Season 2025")
                
                // CTA Buttons
                HStack(spacing: 16) {
                    if isLive {
                        Button(action: onWatchLive) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 18))
                                Text("Watch Live")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.ceremonyRed)
                            .cornerRadius(25)
                            .shadow(color: Color.ceremonyRed.opacity(0.5), radius: 15, x: 0, y: 5)
                        }
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isLive)
                    }
                    
                    if isVotingOpen {
                        Button(action: onVote) {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 18))
                                Text("Cast Your Vote")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.prestigeBlack)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(25)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                    }
                }
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
        }
        .frame(height: 320)
        .cornerRadius(24)
        .padding(.horizontal, 16)
        .onAppear {
            startStarlightAnimation()
            updateTimeRemaining()
        }
    }
    
    private var liveIndicator: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .shadow(color: .red, radius: 10)
            
            Text("LIVE NOW")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .tracking(2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.3))
        .cornerRadius(20)
    }
    
    private var countdownTimer: some View {
        VStack(spacing: 8) {
            Text("Ceremony In")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .tracking(1)
            
            HStack(spacing: 16) {
                timeUnit(value: days, label: "Days")
                timeSeparator
                timeUnit(value: hours, label: "Hours")
                timeSeparator
                timeUnit(value: minutes, label: "Min")
            }
        }
    }
    
    private func timeUnit(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 60)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .cornerRadius(12)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private var timeSeparator: some View {
        Text(":")
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(.white.opacity(0.5))
            .offset(y: -8)
    }
    
    private var days: Int {
        Int(timeRemaining / 86400)
    }
    
    private var hours: Int {
        Int((timeRemaining.truncatingRemainder(dividingBy: 86400)) / 3600)
    }
    
    private var minutes: Int {
        Int((timeRemaining.truncatingRemainder(dividingBy: 3600)) / 60)
    }
    
    private func updateTimeRemaining() {
        timeRemaining = max(0, ceremonyDate.timeIntervalSinceNow)
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            timeRemaining = max(0, ceremonyDate.timeIntervalSinceNow)
        }
    }
    
    private func startStarlightAnimation() {
        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
            starlightOffset = -600
        }
    }
}

// MARK: - Nominee Card

struct NomineeCard: View {
    let nominee: AwardNominee
    let isVoted: Bool
    let onVote: () -> Void
    
    @State private var isFlipped = false
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            if !isFlipped {
                frontCard
            } else {
                backCard
            }
        }
        .frame(width: 200, height: 280)
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
        .onTapGesture {
            isFlipped.toggle()
        }
        .overlay(
            confettiOverlay
                .opacity(showConfetti ? 1 : 0)
                .allowsHitTesting(false)
        )
        .drawingGroup() // Optimize rendering for smooth 60fps
    }
    
    private var frontCard: some View {
        VStack(spacing: 12) {
            // Profile image with gold frame
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.awardGold, Color.awardGold.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 110, height: 110)
                    .shadow(color: Color.awardGold.opacity(0.3), radius: 10)
                
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    )
            }
            
            // Name
            Text(nominee.streamerName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Category badge
            Text(nominee.categoryName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.awardGold.opacity(0.8))
                .cornerRadius(8)
            
            Spacer()
            
            // Vote button
            Button(action: {
                onVote()
                showConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showConfetti = false
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isVoted ? "checkmark.circle.fill" : "hand.raised.fill")
                        .font(.system(size: 14))
                    Text(isVoted ? "Voted" : "Vote")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isVoted ? Color.green : Color.awardGold)
                .cornerRadius(12)
            }
            .disabled(isVoted)
            .scaleEffect(isVoted ? 1.0 : 1.0)
            .accessibilityLabel(isVoted ? "Already voted for \(nominee.streamerName)" : "Vote for \(nominee.streamerName)")
            .accessibilityHint(isVoted ? "" : "Double tap to cast your vote")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.awardGold.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var backCard: some View {
        VStack(spacing: 12) {
            // Stats icon
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 32))
                .foregroundColor(.awardGold)
            
            Text("Stats")
                .font(.system(size: 18, weight: .bold))
            
            Divider()
            
            // Bio/Stats
            VStack(alignment: .leading, spacing: 8) {
                statRow(icon: "eye.fill", label: "Avg Viewers", value: nominee.avgViewers)
                statRow(icon: "clock.fill", label: "Hours Streamed", value: nominee.hoursStreamed)
                statRow(icon: "person.2.fill", label: "Subscribers", value: nominee.subscribers)
            }
            
            Spacer()
            
            // Tap to flip back
            Text("Tap to flip")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.awardGold.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
    }
    
    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.awardGold)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
        }
    }
    
    private var confettiOverlay: some View {
        ZStack {
            ForEach(0..<15, id: \.self) { index in
                Circle()
                    .fill(Color.awardGold)
                    .frame(width: 6, height: 6)
                    .offset(
                        x: CGFloat.random(in: -100...100),
                        y: showConfetti ? -200 : 0
                    )
                    .opacity(showConfetti ? 0 : 1)
                    .animation(.easeOut(duration: 1.0).delay(Double(index) * 0.05), value: showConfetti)
            }
        }
    }
}

// MARK: - Voting Progress Bar

struct VotingProgressBar: View {
    let nominee: AwardNominee
    let totalVotes: Int
    let isLeading: Bool
    
    var percentage: Double {
        guard totalVotes > 0 else { return 0 }
        return Double(nominee.voteCount) / Double(totalVotes)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(nominee.streamerName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                if isLeading {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.awardGold)
                }
                
                Text("\(Int(percentage * 100))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isLeading ? .awardGold : .secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Progress fill with gradient
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: isLeading ? 
                                    [Color.awardGold, Color.awardGold.opacity(0.7)] :
                                    [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: percentage)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Premium Category Card

struct PremiumCategoryCard: View {
    let category: LiveStreamerAwardsSystem.AwardCategory
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon with glow
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    category.color.opacity(0.3),
                                    category.color.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .shadow(color: category.color.opacity(0.3), radius: 10)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 30))
                        .foregroundColor(category.color)
                }
                
                // Name
                Text(category.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Prize in gold
                Text(category.prize)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.awardGold)
                    .lineLimit(1)
                
                // Expand indicator
                if !isExpanded {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.surface,
                                AppTheme.Colors.surface.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.awardGold.opacity(0.3), Color.awardGold.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
            )
            .scaleEffect(isExpanded ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Winner Spotlight Card

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

