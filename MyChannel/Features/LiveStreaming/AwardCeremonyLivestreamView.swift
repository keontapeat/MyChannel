//
//  AwardCeremonyLivestreamView.swift
//  MyChannel
//
//  Award ceremony livestream with winner announcements
//

import SwiftUI
import AVKit

struct AwardCeremonyLivestreamView: View {
    
    @StateObject private var ceremonyManager = AwardCeremonyManager.shared
    @StateObject private var chatService = RealTimeChatService.shared
    @State private var showWinnerAnimation = false
    @State private var currentWinner: AwardWinner?
    @State private var showConfetti = false
    @State private var selectedTab: CeremonyTab = .stream
    
    enum CeremonyTab: String, CaseIterable {
        case stream = "Stream"
        case chat = "Chat"
        case winners = "Winners"
        case schedule = "Schedule"
    }
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Livestream player
                livestreamPlayerView
                
                // Tab bar
                ceremonyTabBar
                
                // Tab content
                TabView(selection: $selectedTab) {
                    streamInfoView
                        .tag(CeremonyTab.stream)
                    
                    ceremonyChatView
                        .tag(CeremonyTab.chat)
                    
                    winnersListView
                        .tag(CeremonyTab.winners)
                    
                    ceremonyScheduleView
                        .tag(CeremonyTab.schedule)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            
            // Winner announcement overlay
            if showWinnerAnimation, let winner = currentWinner {
                WinnerAnnouncementOverlay(winner: winner, isPresented: $showWinnerAnimation)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
            }
            
            // Confetti effect
            if showConfetti {
                AwardConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(99)
            }
        }
        .navigationTitle("Streamer Awards Ceremony")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await ceremonyManager.connectToCeremony()
            try? await chatService.connectToChat(streamId: "award-ceremony-2025")
        }
        .onDisappear {
            // Note: Cannot call async disconnect() from sync context
            Task {
                try? await chatService.disconnectFromChat()
            }
        }
        .onReceive(ceremonyManager.$latestWinner) { winner in
            if let winner = winner {
                announceWinner(winner)
            }
        }
    }
    
    // MARK: - Livestream Player
    private var livestreamPlayerView: some View {
        ZStack {
            if let streamURL = ceremonyManager.streamURL {
                VideoPlayer(player: AVPlayer(url: streamURL))
                    .frame(height: 240)
            } else {
                placeholderStreamView
            }
            
            // Live indicator
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text("LIVE")
                        .font(AppTheme.Typography.caption)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                
                Spacer()
                
                // Viewer count
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                    Text("\(ceremonyManager.viewerCount.formatted())")
                        .font(AppTheme.Typography.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 240)
    }
    
    private var placeholderStreamView: some View {
        ZStack {
            LinearGradient(
                colors: [.purple, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("Awards Ceremony")
                    .font(AppTheme.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if ceremonyManager.isLive {
                    ProgressView()
                        .tint(.white)
                    Text("Loading stream...")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("Ceremony starts soon")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if let startTime = ceremonyManager.ceremonyStartTime {
                        Text("Starting \(startTime, style: .relative)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .frame(height: 240)
    }
    
    // MARK: - Tab Bar
    private var ceremonyTabBar: some View {
        HStack(spacing: 0) {
            ForEach(CeremonyTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(AppTheme.Typography.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                        
                        if selectedTab == tab {
                            Rectangle()
                                .fill(AppTheme.Colors.primary)
                                .frame(height: 2)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
                .foregroundColor(selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
            }
        }
        .background(AppTheme.Colors.cardBackground)
    }
    
    // MARK: - Stream Info Tab
    private var streamInfoView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Ceremony info
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Streamer Awards 2025")
                        .font(AppTheme.Typography.title1)
                    
                    Text(ceremonyManager.ceremonyDescription)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    HStack(spacing: AppTheme.Spacing.md) {
                        Label("\(ceremonyManager.viewerCount.formatted()) watching", systemImage: "eye.fill")
                        Label("26 categories", systemImage: "trophy.fill")
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                
                Divider()
                
                // Current category
                if let currentCategory = ceremonyManager.currentCategory {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("NOW PRESENTING")
                            .font(AppTheme.Typography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        HStack {
                            Image(systemName: currentCategory.icon)
                                .font(.system(size: 30))
                                .foregroundColor(currentCategory.color)
                            
                            Text(currentCategory.name)
                                .font(AppTheme.Typography.headline)
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Colors.cardBackground)
                    .cornerRadius(AppTheme.CornerRadius.lg)
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
                
                // Prize pool
                prizPoolView
                
                // Hosts
                ceremonyHostsView
            }
            .padding(.vertical, AppTheme.Spacing.lg)
        }
    }
    
    private var prizPoolView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Prize Pool")
                .font(AppTheme.Typography.headline)
                .padding(.horizontal, AppTheme.Spacing.md)
            
            VStack(spacing: AppTheme.Spacing.sm) {
                PrizeRowView(
                    title: "Streamer of the Year",
                    prize: "$50,000",
                    icon: "crown.fill",
                    color: .yellow
                )
                
                PrizeRowView(
                    title: "Other Category Winners",
                    prize: "$5,000 each",
                    icon: "trophy.fill",
                    color: .blue
                )
                
                PrizeRowView(
                    title: "Total Prize Pool",
                    prize: "$175,000",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
    
    private var ceremonyHostsView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Hosted by")
                .font(AppTheme.Typography.headline)
                .padding(.horizontal, AppTheme.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.md) {
                    ForEach(ceremonyManager.hosts, id: \.id) { host in
                        HostCardView(host: host)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
    }
    
    // MARK: - Ceremony Chat Tab
    private var ceremonyChatView: some View {
        VStack(spacing: 0) {
            // Chat messages
            ScrollView {
                LazyVStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(chatService.messages) { message in
                        ChatMessageRow(message: message)
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            
            // Chat input
            ChatInputView(onSend: { messageText in
                Task {
                    let message = LiveChatMessage(
                        streamId: "award-ceremony-2025",
                        userId: "current-user", // TODO: Get from auth
                        username: "Guest",
                        content: messageText
                    )
                    try? await chatService.sendMessage(message)
                }
            })
        }
    }
    
    // MARK: - Winners List Tab
    private var winnersListView: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.md) {
                ForEach(ceremonyManager.announcedWinners) { winner in
                    WinnerCardView(winner: winner)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
    }
    
    // MARK: - Ceremony Schedule Tab
    private var ceremonyScheduleView: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.sm) {
                ForEach(ceremonyManager.schedule, id: \.categoryId) { item in
                    ScheduleItemRow(item: item)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
    }
    
    // MARK: - Winner Announcement
    private func announceWinner(_ winner: AwardWinner) {
        currentWinner = winner
        
        withAnimation(AppTheme.AnimationPresets.spring) {
            showWinnerAnimation = true
            showConfetti = true
        }
        
        // Hide after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(AppTheme.AnimationPresets.easeInOut) {
                showWinnerAnimation = false
            }
        }
        
        // Stop confetti after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            showConfetti = false
        }
    }
}

// MARK: - Prize Row View

struct PrizeRowView: View {
    let title: String
    let prize: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(AppTheme.Typography.body)
            
            Spacer()
            
            Text(prize)
                .font(AppTheme.Typography.headline)
                .foregroundColor(color)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
    }
}

// MARK: - Host Card View

struct HostCardView: View {
    let host: CeremonyHost
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            AsyncImage(url: URL(string: host.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            
            Text(host.displayName)
                .font(AppTheme.Typography.caption)
                .fontWeight(.semibold)
            
            Text("Host")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(width: 100)
    }
}

// MARK: - Winner Card View

struct WinnerCardView: View {
    let winner: AwardWinner
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Trophy icon
            Image(systemName: "trophy.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(winner.categoryName)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text(winner.winnerName)
                    .font(AppTheme.Typography.headline)
                    .fontWeight(.bold)
                
                Text("Won \(winner.prizeAmount)")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            // Profile image
            AsyncImage(url: URL(string: winner.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.lg)
    }
}

// MARK: - Schedule Item Row

struct ScheduleItemRow: View {
    let item: CeremonyScheduleItem
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Time
            Text(item.time)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(width: 60, alignment: .leading)
            
            // Category
            VStack(alignment: .leading, spacing: 2) {
                Text(item.categoryName)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                
                if item.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Winner: \(item.winnerName ?? "TBA")")
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(.green)
                } else if item.isCurrentlyPresenting {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("NOW PRESENTING")
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(.red)
                }
            }
            
            Spacer()
        }
        .padding(AppTheme.Spacing.sm)
        .background(item.isCurrentlyPresenting ? AppTheme.Colors.primary.opacity(0.1) : AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
    }
}

// MARK: - Winner Announcement Overlay

struct WinnerAnnouncementOverlay: View {
    let winner: AwardWinner
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isPresented = false
                    }
                }
            
            // Winner card
            VStack(spacing: AppTheme.Spacing.lg) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow, radius: 20)
                
                Text("WINNER!")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                
                Text(winner.categoryName)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(.white.opacity(0.8))
                
                // Winner profile
                AsyncImage(url: URL(string: winner.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.yellow, lineWidth: 4)
                )
                
                Text(winner.winnerName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text(winner.prizeAmount)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.green)
            }
            .padding(AppTheme.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl)
                    .fill(Color.black.opacity(0.9))
            )
            .padding(AppTheme.Spacing.xl)
            .scaleEffect(isPresented ? 1 : 0.5)
        }
    }
}

// MARK: - Award Confetti View

struct AwardConfettiView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<50) { index in
                AwardConfettiPiece()
                    .offset(
                        x: CGFloat.random(in: -200...200),
                        y: animate ? 1000 : -100
                    )
                    .rotationEffect(.degrees(animate ? 360 : 0))
                    .animation(
                        .linear(duration: Double.random(in: 2...4))
                        .repeatForever(autoreverses: false)
                        .delay(Double.random(in: 0...0.5)),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct AwardConfettiPiece: View {
    let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .pink, .orange]
    let randomColor: Color
    
    init() {
        randomColor = colors.randomElement() ?? .blue
    }
    
    var body: some View {
        Rectangle()
            .fill(randomColor)
            .frame(width: 10, height: 10)
    }
}

// MARK: - Chat Input View

struct ChatInputView: View {
    let onSend: (String) -> Void
    @State private var messageText = ""
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            TextField("Send a message...", text: $messageText)
                .textFieldStyle(.plain)
                .padding(AppTheme.Spacing.sm)
                .background(AppTheme.Colors.cardBackground)
                .cornerRadius(AppTheme.CornerRadius.md)
            
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(messageText.isEmpty ? Color.gray : AppTheme.Colors.primary)
                    .clipShape(Circle())
            }
            .disabled(messageText.isEmpty)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.background)
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        onSend(messageText)
        messageText = ""
    }
}

// MARK: - Chat Message Row

struct ChatMessageRow: View {
    let message: LiveChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            AsyncImage(url: URL(string: message.userAvatarURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(width: 30, height: 30)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(message.username)
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(message.content)
                    .font(AppTheme.Typography.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview("Award Ceremony") {
    NavigationView {
        AwardCeremonyLivestreamView()
    }
}

