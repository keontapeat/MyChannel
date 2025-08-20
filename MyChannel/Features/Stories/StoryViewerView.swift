//
//  StoryViewerView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import AVKit
import UIKit

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

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

                // Main story content
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
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: currentContentIndex)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white.opacity(0.6))

                        Text("Loading Story...")
                            .font(.title2)
                            .foregroundColor(.white)

                        Button("Close") {
                            onDismiss()
                        }
                        .padding()
                        .background(AppTheme.Colors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }

                // Professional gradient overlays
                VStack {
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

                    if showingText, let text = currentContent?.text {
                        EnhancedStoryTextOverlay(
                            text: text,
                            backgroundColor: currentContent?.backgroundColor
                        )
                        .transition(.scale.combined(with: .opacity))
                        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8), value: showingText)
                    }

                    Spacer()

                    EnhancedStoryFooterView(
                        story: currentStory,
                        hasLiked: hasLiked,
                        onReply: { showingReply = true },
                        onLike: {
                            if reduceMotion {
                                hasLiked.toggle()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    hasLiked.toggle()
                                }
                            }
                            hapticFeedback.impactOccurred()
                        },
                        onShare: { hapticFeedback.impactOccurred() }
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
                    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: isPaused)
                }
            }
            // Scrub overlay at top over progress bars
            .overlay(alignment: .top) {
                Color.clear
                    .frame(height: 28)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                pauseStory()
                                scrub(atX: value.location.x, totalWidth: geometry.size.width)
                            }
                            .onEnded { _ in
                                resumeStory()
                            }
                    )
                    .padding(.top, 8)
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
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
        .onAppear {
            setupInitialStory()
            startStoryTimer()
            simulateViewerCount()
        }
        .onDisappear {
            stopStoryTimer()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active: resumeStory()
            case .inactive, .background: pauseStory()
            @unknown default: pauseStory()
            }
        }
        .statusBarHidden()
        .sheet(isPresented: $showingReply) {
            StoryReplyView(
                story: currentStory,
                onSend: { message in
                    showingReply = false
                }
            )
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingProfile) {
            if let creator = currentStory.creator {
                NavigationStack {
                    VStack(spacing: 20) {
                        AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                )
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())

                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Text(creator.displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                if creator.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }

                            Text("@\(creator.username)")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)

                            if let bio = creator.bio {
                                Text(bio)
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }

                        HStack(spacing: 30) {
                            VStack {
                                Text("\(creator.subscriberCount)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text("Subscribers")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }

                            VStack {
                                Text("\(creator.videoCount)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text("Videos")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }

                        Button(action: {}) {
                            Text("Subscribe")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.Colors.primary)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)

                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                showingProfile = false
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    private func simulateViewerCount() {
        viewerCount = Int.random(in: 50...2000)
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
            previousContent()
        } else if location.x > screenWidth * 2/3 {
            nextContent()
        } else {
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
            hapticFeedback.impactOccurred()
            onDismiss()
        } else if translation.height < -50 {
            showingProfile = true
        } else if abs(translation.width) > 100 {
            if translation.width > 0 {
                previousStory()
            } else {
                nextStory()
            }
        }
    }

    private func nextContent() {
        if currentContentIndex < currentStory.content.count - 1 {
            if reduceMotion {
                currentContentIndex += 1
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { currentContentIndex += 1 }
            }
            resetProgress()
        } else {
            nextStory()
        }
        updateTextVisibility()
    }

    private func previousContent() {
        if currentContentIndex > 0 {
            if reduceMotion {
                currentContentIndex -= 1
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { currentContentIndex -= 1 }
            }
            resetProgress()
        } else {
            previousStory()
        }
        updateTextVisibility()
    }

    private func nextStory() {
        if currentStoryIndex < stories.count - 1 {
            if reduceMotion {
                currentStoryIndex += 1
                currentContentIndex = 0
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStoryIndex += 1
                    currentContentIndex = 0
                }
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
            if reduceMotion {
                currentStoryIndex -= 1
                currentContentIndex = max(0, currentStory.content.count - 1)
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStoryIndex -= 1
                    currentContentIndex = max(0, currentStory.content.count - 1)
                }
            }
            resetProgress()
            simulateViewerCount()
        } else {
            onDismiss()
        }
        updateTextVisibility()
    }

    private func updateTextVisibility() {
        if reduceMotion {
            showingText = currentContent?.type == .text
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingText = currentContent?.type == .text
            }
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
        if reduceMotion {
            isPaused = true
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPaused = true }
        }
    }

    private func resumeStory() {
        if reduceMotion {
            isPaused = false
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPaused = false }
        }
    }

    // MARK: - Scrubbing
    private func scrub(atX x: CGFloat, totalWidth: CGFloat) {
        let bars = max(1, currentStory.content.count)
        let spacing: CGFloat = 3
        let innerWidth = totalWidth - 16 - CGFloat(bars - 1) * spacing
        let step = innerWidth / CGFloat(bars)
        let clampedX = max(0, min(x - 8, innerWidth + CGFloat(bars - 1) * spacing))
        let newIndex = Int(clampedX / (step + spacing))
        let remainder = clampedX - CGFloat(newIndex) * (step + spacing)
        let localProgress = max(0, min(1, remainder / step))

        if newIndex != currentContentIndex {
            currentContentIndex = newIndex
            startStoryTimer()
        }
        progress = Double(localProgress)
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
            let urlString = content.url
            if let url = URL(string: urlString), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .scaleEffect(isPaused ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: isPaused)
                            .onAppear { imageLoaded = true }
                    case .failure(_):
                        failurePlaceholder
                    case .empty:
                        loadingPlaceholder
                    @unknown default:
                        EmptyView()
                    }
                }
            } else if UIImage(named: urlString) != nil {
                Image(urlString)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .scaleEffect(isPaused ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isPaused)
            } else {
                failurePlaceholder
            }

        case .video:
            ZStack {
                LinearGradient(
                    colors: [AppTheme.Colors.primary.opacity(0.6), AppTheme.Colors.secondary.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 20) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .shadow(radius: 4)

                    Text("Video Story")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Tap to play")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .text:
            ZStack {
                let bgColor = content.backgroundColor ?? "#FF6B6B"
                Color(hex: bgColor)

                if let text = content.text {
                    Text(text)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .music:
            ZStack {
                LinearGradient(
                    colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.8), Color.orange.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 24) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                        .shadow(radius: 4)

                    VStack(spacing: 8) {
                        Text("Music Story")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Now Playing")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var failurePlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.Colors.primary.opacity(0.8), AppTheme.Colors.secondary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 16) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.9))
                Text("Story Image")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Image temporarily unavailable")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingPlaceholder: some View {
        ZStack {
            AppTheme.Colors.surface
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                    .scaleEffect(1.5)
                Text("Loading story...")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

                    Text("Comment")
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

            HStack(spacing: 16) {
                Button(action: onLike) {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.4))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )

                        Image(systemName: hasLiked ? "heart.fill" : "heart")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(hasLiked ? .red : .white)
                            .scaleEffect(hasLiked ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasLiked)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: onShare) {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.4))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )

                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(45))
                    }
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
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