//
//  StoryViewerView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import AVKit

struct StoryViewerView: View {
    let stories: [Story]
    let initialStory: Story
    let onDismiss: () -> Void
    
    @State private var currentStoryIndex: Int = 0
    @State private var currentContentIndex: Int = 0
    @State private var progress: Double = 0.0
    @State private var isPaused: Bool = false
    @State private var timer: Timer?
    @State private var dragOffset: CGSize = .zero
    @State private var showingText: Bool = false
    @State private var showingReply: Bool = false
    @State private var replyText: String = ""
    @State private var viewerCount: Int = 0
    @State private var hasLiked: Bool = false
    @State private var showingProfile: Bool = false
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    private var currentStory: Story {
        stories[currentStoryIndex]
    }
    
    private var currentContent: StoryContent? {
        guard currentContentIndex < currentStory.content.count else { return nil }
        return currentStory.content[currentContentIndex]
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                // Enhanced story content with better quality
                if let content = currentContent {
                    EnhancedStoryContentView(
                        content: content,
                        isPaused: isPaused,
                        geometry: geometry
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.1)),
                        removal: .opacity.combined(with: .scale(scale: 0.9))
                    ))
                    .animation(.easeInOut(duration: 0.3), value: currentContentIndex)
                }
                
                // Professional gradient overlays
                VStack {
                    // Top gradient
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.8),
                            Color.black.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    
                    Spacer()
                    
                    // Bottom gradient
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 140)
                }
                .ignoresSafeArea()
                
                // Enhanced story controls overlay
                VStack(spacing: 0) {
                    EnhancedStoryHeaderView(
                        story: currentStory,
                        progress: progress,
                        contentCount: currentStory.content.count,
                        currentIndex: currentContentIndex,
                        viewerCount: viewerCount,
                        onDismiss: onDismiss,
                        onProfileTap: {
                            showingProfile = true
                        }
                    )
                    
                    Spacer()
                    
                    // Text overlay with better styling
                    if showingText, let text = currentContent?.text {
                        EnhancedStoryTextOverlay(
                            text: text,
                            backgroundColor: currentContent?.backgroundColor
                        )
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showingText)
                    }
                    
                    Spacer()
                    
                    EnhancedStoryFooterView(
                        story: currentStory,
                        hasLiked: hasLiked,
                        onReply: {
                            showingReply = true
                        },
                        onLike: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                hasLiked.toggle()
                                hapticFeedback.impactOccurred()
                            }
                        },
                        onShare: {
                            // Handle share
                            hapticFeedback.impactOccurred()
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
                
                // Pause indicator
                if isPaused {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(.white)
                                .frame(width: 4, height: 20)
                                .cornerRadius(2)
                            
                            Rectangle()
                                .fill(.white)
                                .frame(width: 4, height: 20)
                                .cornerRadius(2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.6))
                        .cornerRadius(20)
                        .scaleEffect(1.2)
                        .shadow(radius: 10)
                        
                        Spacer()
                    }
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPaused)
                }
            }
        }
        .onTapGesture { location in
            handleTapGesture(at: location)
        }
        .onLongPressGesture(minimumDuration: 0.2) {
            pauseStory()
        } onPressingChanged: { pressing in
            if !pressing {
                resumeStory()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    
                    // Add resistance for upward swipes
                    if dragOffset.height < 0 {
                        dragOffset.height = dragOffset.height * 0.3
                    }
                }
                .onEnded { value in
                    handleSwipeGesture(translation: value.translation)
                    dragOffset = .zero
                }
        )
        .offset(dragOffset)
        .scaleEffect(dragOffset.height > 0 ? max(0.8, 1 - dragOffset.height / 1000) : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
        .onAppear {
            setupInitialStory()
            startStoryTimer()
            simulateViewerCount()
        }
        .onDisappear {
            stopStoryTimer()
        }
        .statusBarHidden()
        .sheet(isPresented: $showingReply) {
            StoryReplyView(
                story: currentStory,
                onSend: { message in
                    print("💬 Reply sent: \(message)")
                    showingReply = false
                }
            )
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingProfile) {
            if let creator = currentStory.creator {
                CreatorProfileView(creator: creator)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func simulateViewerCount() {
        viewerCount = Int.random(in: 50...2000)
        
        // Simulate live viewer count updates
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            let change = Int.random(in: -5...15)
            viewerCount = max(1, viewerCount + change)
        }
    }
    
    private func setupInitialStory() {
        if let initialIndex = stories.firstIndex(where: { $0.id == initialStory.id }) {
            currentStoryIndex = initialIndex
        }
        
        updateTextVisibility()
    }
    
    private func handleTapGesture(at location: CGPoint) {
        let screenWidth = UIScreen.main.bounds.width
        
        hapticFeedback.impactOccurred()
        
        if location.x < screenWidth / 3 {
            // Left tap - previous content/story
            previousContent()
        } else if location.x > screenWidth * 2/3 {
            // Right tap - next content/story
            nextContent()
        } else {
            // Center tap - pause/resume
            if isPaused {
                resumeStory()
            } else {
                pauseStory()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    resumeStory()
                }
            }
        }
    }
    
    private func handleSwipeGesture(translation: CGSize) {
        if translation.height > 150 {
            // Swipe down - dismiss with haptic feedback
            hapticFeedback.impactOccurred()
            onDismiss()
        } else if translation.height < -50 {
            // Swipe up - show creator profile
            showingProfile = true
        } else if abs(translation.width) > 100 {
            // Horizontal swipe - navigate stories
            if translation.width > 0 {
                previousStory()
            } else {
                nextStory()
            }
        }
    }
    
    private func nextContent() {
        if currentContentIndex < currentStory.content.count - 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentContentIndex += 1
            }
            resetProgress()
        } else {
            nextStory()
        }
        
        updateTextVisibility()
    }
    
    private func previousContent() {
        if currentContentIndex > 0 {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentContentIndex -= 1
            }
            resetProgress()
        } else {
            previousStory()
        }
        
        updateTextVisibility()
    }
    
    private func nextStory() {
        if currentStoryIndex < stories.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStoryIndex += 1
                currentContentIndex = 0
            }
            resetProgress()
            simulateViewerCount()
        } else {
            onDismiss()
        }
        
        updateTextVisibility()
    }
    
    private func previousStory() {
        if currentStoryIndex > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStoryIndex -= 1
                currentContentIndex = max(0, currentStory.content.count - 1)
            }
            resetProgress()
            simulateViewerCount()
        } else {
            onDismiss()
        }
        
        updateTextVisibility()
    }
    
    private func updateTextVisibility() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingText = currentContent?.type == .text
        }
    }
    
    private func startStoryTimer() {
        guard let content = currentContent else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if !isPaused {
                progress += 0.05 / content.duration
                
                if progress >= 1.0 {
                    nextContent()
                }
            }
        }
    }
    
    private func stopStoryTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func resetProgress() {
        progress = 0.0
        stopStoryTimer()
        startStoryTimer()
    }
    
    private func pauseStory() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isPaused = true
        }
    }
    
    private func resumeStory() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isPaused = false
        }
    }
}

// MARK: - Enhanced Story Content View
struct EnhancedStoryContentView: View {
    let content: StoryContent
    let isPaused: Bool
    let geometry: GeometryProxy
    
    @State private var imageLoaded: Bool = false
    @State private var loadingAnimation: Bool = false
    
    var body: some View {
        switch content.type {
        case .image:
            AsyncImage(url: URL(string: content.url)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .scaleEffect(isPaused ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isPaused)
                        .onAppear {
                            imageLoaded = true
                        }
                        
                case .failure(_):
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(AppTheme.Colors.textTertiary)
                                .font(.title)
                        )
                        
                case .empty:
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                        )
                        
                @unknown default:
                    EmptyView()
                }
            }
            
        case .video:
            // Video player implementation
            Rectangle()
                .fill(AppTheme.Colors.surface)
                .overlay(
                    VStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                        Text("Video content")
                            .foregroundColor(.white)
                    }
                )
            
        case .text:
            Rectangle()
                .fill(Color(hex: content.backgroundColor ?? "#FF6B6B"))
                .overlay(
                    VStack {
                        if let text = content.text {
                            Text(text)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                    }
                )
            
        case .music:
            Rectangle()
                .fill(AppTheme.Colors.surface)
                .overlay(
                    VStack {
                        Image(systemName: "music.note")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                        Text("Music content")
                            .foregroundColor(.white)
                    }
                )
        }
    }
}

// MARK: - Enhanced Story Header View
struct EnhancedStoryHeaderView: View {
    let story: Story
    let progress: Double
    let contentCount: Int
    let currentIndex: Int
    let viewerCount: Int
    let onDismiss: () -> Void
    let onProfileTap: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Enhanced progress bars
            HStack(spacing: 3) {
                ForEach(0..<contentCount, id: \.self) { index in
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(.white.opacity(0.3))
                                .frame(height: 3)
                                .cornerRadius(1.5)
                            
                            Rectangle()
                                .fill(.white)
                                .frame(width: geometry.size.width * progressForIndex(index), height: 3)
                                .cornerRadius(1.5)
                                .animation(.linear(duration: 0.1), value: progress)
                        }
                    }
                    .frame(height: 3)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            // Enhanced story info
            HStack(spacing: 12) {
                Button(action: onProfileTap) {
                    ZStack(alignment: .bottomTrailing) {
                        AsyncImage(url: URL(string: story.creator?.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(.white.opacity(0.3))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                )
                        }
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        // Online indicator
                        if story.creator?.isCreator == true {
                            Circle()
                                .fill(AppTheme.Colors.success)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                )
                                .offset(x: 2, y: 2)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(story.creator?.displayName ?? "Unknown")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if story.creator?.isVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        
                        if story.isLive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 4, height: 4)
                                    .scaleEffect(1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: true)
                                
                                Text("LIVE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.primary)
                            .cornerRadius(8)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text(story.createdAt.timeAgoDisplay)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                        
                        if viewerCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 10))
                                
                                Text("\(viewerCount)")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.4))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func progressForIndex(_ index: Int) -> Double {
        if index < currentIndex {
            return 1.0
        } else if index == currentIndex {
            return progress
        } else {
            return 0.0
        }
    }
}

// MARK: - Enhanced Story Text Overlay
struct EnhancedStoryTextOverlay: View {
    let text: String
    let backgroundColor: String?
    
    var body: some View {
        Text(text)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.black.opacity(0.6))
                        .blur(radius: 1)
                    
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                }
            )
            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Enhanced Story Footer View
struct EnhancedStoryFooterView: View {
    let story: Story
    let hasLiked: Bool
    let onReply: () -> Void
    let onLike: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onReply) {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.right.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    
                    Text("Send message")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(.white.opacity(0.6), lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(.white.opacity(0.1))
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack(spacing: 20) {
                Button(action: onLike) {
                    Image(systemName: hasLiked ? "heart.fill" : "heart")
                        .font(.system(size: 24))
                        .foregroundColor(hasLiked ? .red : .white)
                        .scaleEffect(hasLiked ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasLiked)
                }
                .buttonStyle(PlainButtonStyle())
                
                ShareLink(item: URL(string: "https://mychannel.app/story/\(story.id)")!) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Story Reply View
struct StoryReplyView: View {
    let story: Story
    let onSend: (String) -> Void
    
    @State private var replyText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 6)
                .padding(.top, 8)
            
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: story.creator?.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                
                Text("Reply to \(story.creator?.displayName ?? "Unknown")")
                    .font(.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal)
            
            HStack(spacing: 12) {
                TextField("Write a message...", text: $replyText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .lineLimit(1...3)
                
                Button(action: {
                    if !replyText.isEmpty {
                        onSend(replyText)
                        replyText = ""
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(replyText.isEmpty ? .gray : AppTheme.Colors.primary)
                }
                .disabled(replyText.isEmpty)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

#Preview {
    StoryViewerView(
        stories: Story.sampleStories,
        initialStory: Story.sampleStories[0],
        onDismiss: {}
    )
}