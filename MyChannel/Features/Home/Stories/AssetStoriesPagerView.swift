import SwiftUI
import AVKit

// MARK: - Instagram-Style Stories Pager
// Groups stories by user. Progress bars = one per story within current user.
// After last story of a user → auto-advance to next user.
// Swipe left/right = jump between users. Tap left/right = prev/next story.
// Swipe down = dismiss. Long press = pause. Double-tap = like.

struct AssetStoriesPagerView: View {
    let allStories: [AssetStory]
    let userGroups: [UserStoryGroup]
    let initialUserIndex: Int
    let onDismiss: () -> Void

    @State private var userIndex: Int
    @State private var storyIndex: Int = 0
    @State private var progress: Double = 0
    @State private var isPaused: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var timer: Timer?
    @State private var transitionDirection: Int = 0 // -1 left, 0 none, 1 right

    // UX
    @State private var showHeart: Bool = false
    @State private var heartScale: CGFloat = 0.6
    @State private var headerVisible: Bool = true

    // Three-dot menu
    @State private var showStoryOptions: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var isDeletingStory: Bool = false

    @EnvironmentObject private var appState: AppState

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Tunables
    private let imageDuration: TimeInterval = 5.0
    private let videoDuration: TimeInterval = 8.0

    // Legacy init (flat story list, single user)
    init(stories: [AssetStory], initialIndex: Int = 0, onDismiss: @escaping () -> Void) {
        self.allStories = stories
        self.userGroups = UserStoryGroup.group(from: stories)
        self.initialUserIndex = 0
        self.onDismiss = onDismiss
        _userIndex = State(initialValue: 0)
        _storyIndex = State(initialValue: min(max(0, initialIndex), max(stories.count - 1, 0)))
    }

    // Instagram-style init (grouped by user)
    init(userGroups: [UserStoryGroup], initialUserIndex: Int = 0, onDismiss: @escaping () -> Void) {
        self.allStories = userGroups.flatMap { $0.stories }
        self.userGroups = userGroups
        let safeIdx = min(max(0, initialUserIndex), max(userGroups.count - 1, 0))
        self.initialUserIndex = safeIdx
        self.onDismiss = onDismiss
        _userIndex = State(initialValue: safeIdx)
    }

    private var currentGroup: UserStoryGroup? {
        guard userIndex >= 0 && userIndex < userGroups.count else { return nil }
        return userGroups[userIndex]
    }

    private var currentStory: AssetStory? {
        guard let group = currentGroup,
              storyIndex >= 0 && storyIndex < group.stories.count else { return nil }
        return group.stories[storyIndex]
    }

    private var storiesInCurrentGroup: Int {
        currentGroup?.stories.count ?? 1
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let story = currentStory {
                    storyContentView(for: story)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .scaleEffect(isPaused ? 1.02 : 1.0)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isPaused)
                        .id("\(userIndex)-\(storyIndex)")
                        .transition(.asymmetric(
                            insertion: .move(edge: transitionDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: transitionDirection >= 0 ? .leading : .trailing).combined(with: .opacity)
                        ))
                }

                // Top overlays: progress + header
                VStack(spacing: 12) {
                    progressBars
                        .padding(.horizontal, 10)

                    header
                        .padding(.horizontal, 12)
                        .opacity(headerVisible ? 1 : 0)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: headerVisible)
                }
                .padding(.top, 14)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.85), Color.black.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 160)
                    .ignoresSafeArea()
                    .frame(maxHeight: .infinity, alignment: .top)
                )

                // Bottom gradient + actions
                VStack(spacing: 0) {
                    Spacer()
                    bottomActions
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                        .opacity(headerVisible ? 1 : 0)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: headerVisible)
                }
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.6)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 200)
                    .ignoresSafeArea()
                    .frame(maxHeight: .infinity, alignment: .bottom)
                )

                // Invisible tap regions (prev/next) — Instagram: left = prev story, right = next story
                HStack(spacing: 0) {
                    Rectangle().fill(.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { previousStory() }
                    Rectangle().fill(.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { nextStory() }
                }
                .allowsHitTesting(true)

                // Double-tap like
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        likeBurst()
                    }

                // Pause indicator
                if isPaused {
                    Image(systemName: "pause.fill")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.35), in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }

                // Heart animation
                if showHeart {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 90))
                        .foregroundStyle(.red)
                        .scaleEffect(heartScale)
                        .opacity(heartScale >= 1.0 ? 0.0 : 1.0)
                        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
                        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: heartScale)
                }
            }
            // Swipe gesture — Instagram: horizontal = next/prev USER, vertical down = dismiss
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                        headerVisible = false
                    }
                    .onEnded { value in
                        defer { dragOffset = .zero; headerVisible = true }
                        if value.translation.height > 120 {
                            HapticManager.shared.impact(style: .light)
                            onDismiss()
                            return
                        }
                        // Swipe left/right = jump between USERS (Instagram cube transition)
                        if value.translation.width < -80 {
                            nextUser()
                        } else if value.translation.width > 80 {
                            previousUser()
                        }
                    }
            )
            .offset(dragOffset)
            .scaleEffect(dragOffset.height > 0 ? max(0.85, 1 - dragOffset.height / 900) : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: dragOffset)
            .onLongPressGesture(minimumDuration: 0.15) {
                pause()
            } onPressingChanged: { pressing in
                if !pressing { resume() }
            }
            .onAppear {
                startTimer()
            }
            .onDisappear { stopTimer() }
        }
        .statusBarHidden()
        .ignoresSafeArea()
        .alert("Delete this story?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deleteCurrentStory()
            }
            Button("Cancel", role: .cancel) {
                resume()
            }
        } message: {
            Text("This will permanently remove the story for everyone.")
        }
        .onChange(of: scenePhase) { newValue in
            switch newValue {
            case .active: resume()
            case .inactive, .background: pause()
            @unknown default: pause()
            }
        }
    }

    // MARK: - Content
    @ViewBuilder
    private func storyContentView(for story: AssetStory) -> some View {
        switch story.media {
        case .image(let name):
            if let remoteURL = URL(string: name), remoteURL.scheme == "https" || remoteURL.scheme == "http" {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    case .failure:
                        ZStack {
                            Color.black
                            VStack(spacing: 12) {
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("Could not load image")
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    case .empty:
                        ZStack {
                            LinearGradient(
                                colors: [.gray.opacity(0.3), .gray.opacity(0.15)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            ProgressView().tint(.white)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            } else if let ui = UIImage(named: name) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ZStack {
                    Color.black
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Image not found")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        case .video(let resource):
            if let remoteURL = URL(string: resource), remoteURL.scheme == "https" || remoteURL.scheme == "http" {
                RawPlayerLayerView(player: AVPlayer(url: remoteURL), videoGravity: .resizeAspectFill)
                    .transition(.opacity)
            } else if let url = Bundle.main.url(forResource: resource, withExtension: nil) {
                RawPlayerLayerView(player: AVPlayer(url: url), videoGravity: .resizeAspectFill)
                    .transition(.opacity)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [.purple.opacity(0.7), .blue.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    VStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.white)
                        Text("Video not found")
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
        }
    }

    // MARK: - Progress Bars (per story within current user)
    private var progressBars: some View {
        HStack(spacing: 4) {
            ForEach(0..<storiesInCurrentGroup, id: \.self) { i in
                GeometryReader { barGeo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.25))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: fillWidth(for: i, totalWidth: barGeo.size.width))
                            .animation(reduceMotion ? nil : .linear(duration: 0.05), value: progress)
                    }
                }
                .frame(height: 2.5)
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                storyAvatar(for: currentGroup)
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                Text(currentGroup?.username ?? "")
                    .foregroundStyle(.white)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 10) {
                Button {
                    HapticManager.shared.selection()
                    pause()
                    showStoryOptions = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.35), in: Circle())
                }
                .confirmationDialog("", isPresented: $showStoryOptions, titleVisibility: .hidden) {
                    let isOwner = currentStory?.creatorId == appState.currentUser?.id
                    if isOwner {
                        Button("Delete Story", role: .destructive) {
                            showDeleteConfirm = true
                        }
                        Button("Archive Story") {
                            archiveCurrentStory()
                        }
                    }
                    Button("Save to Photos") {
                        saveCurrentStoryToPhotos()
                    }
                    Button("Report", role: .destructive) {
                        resume()
                    }
                    Button("Cancel", role: .cancel) {
                        resume()
                    }
                }

                Button {
                    onDismiss()
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.35), in: Circle())
                }
            }
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 14) {
            HStack {
                Text("Send message")
                    .foregroundStyle(.white.opacity(0.85))
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.12), in: Capsule())

            Button {
                likeBurst()
            } label: {
                Image(systemName: "heart\(showHeart ? ".fill" : "")")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(showHeart ? .red : .white)
                    .padding(10)
                    .background(Color.black.opacity(0.35), in: Circle())
            }

            Button {
                HapticManager.shared.selection()
            } label: {
                Image(systemName: "paperplane.fill")
                    .rotationEffect(.degrees(45))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.35), in: Circle())
            }
        }
    }

    private func storyAvatar(for group: UserStoryGroup?) -> some View {
        Group {
            let imgName = group?.authorImageName ?? ""
            if let remoteURL = URL(string: imgName), remoteURL.scheme == "https" || remoteURL.scheme == "http" {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default:
                        Circle().fill(Color.white.opacity(0.25))
                            .overlay(
                                Text(String((group?.username ?? "").prefix(2)).uppercased())
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                }
            } else if let img = UIImage(named: imgName) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Circle().fill(Color.white.opacity(0.25))
                    .overlay(
                        Text(String((group?.username ?? "").prefix(2)).uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
    }

    // MARK: - Timing
    private func durationForCurrent() -> TimeInterval {
        guard let story = currentStory else { return imageDuration }
        switch story.media {
        case .image: return imageDuration
        case .video: return videoDuration
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard !isPaused else { return }
            let step = 0.05 / max(0.2, durationForCurrent())
            progress += step
            if progress >= 1.0 { nextStory() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func resetProgress() {
        progress = 0
        startTimer()
    }

    private func pause() {
        if reduceMotion {
            isPaused = true
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isPaused = true }
        }
    }

    private func resume() {
        if reduceMotion {
            isPaused = false
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isPaused = false }
        }
    }

    // MARK: - Navigation (Instagram logic)

    /// Tap right / timer expires → next story within user, or next user if last story
    private func nextStory() {
        let count = storiesInCurrentGroup
        if storyIndex < count - 1 {
            // Next story within same user
            transitionDirection = 1
            if reduceMotion {
                storyIndex += 1
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { storyIndex += 1 }
            }
            HapticManager.shared.selection()
            resetProgress()
        } else {
            // Last story of this user → mark as seen, advance to next user
            markCurrentUserSeen()
            nextUser()
        }
    }

    /// Tap left → previous story within user, or previous user if first story
    private func previousStory() {
        if storyIndex > 0 {
            transitionDirection = -1
            if reduceMotion {
                storyIndex -= 1
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { storyIndex -= 1 }
            }
            HapticManager.shared.selection()
            resetProgress()
        } else {
            previousUser()
        }
    }

    /// Swipe left / auto-advance → next user
    private func nextUser() {
        markCurrentUserSeen()
        if userIndex < userGroups.count - 1 {
            transitionDirection = 1
            if reduceMotion {
                userIndex += 1
                storyIndex = 0
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    userIndex += 1
                    storyIndex = 0
                }
            }
            HapticManager.shared.impact(style: .light)
            resetProgress()
        } else {
            // Last user → dismiss (Instagram behavior)
            onDismiss()
        }
    }

    /// Swipe right → previous user (start from their first story)
    private func previousUser() {
        if userIndex > 0 {
            transitionDirection = -1
            if reduceMotion {
                userIndex -= 1
                storyIndex = 0
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    userIndex -= 1
                    storyIndex = 0
                }
            }
            HapticManager.shared.impact(style: .light)
            resetProgress()
        } else {
            onDismiss()
        }
    }

    /// Mark the current user's stories as seen
    private func markCurrentUserSeen() {
        guard let group = currentGroup else { return }
        StorySeenTracker.shared.markSeen(username: group.username)
    }

    private func fillWidth(for barIndex: Int, totalWidth: CGFloat) -> CGFloat {
        if barIndex < storyIndex { return totalWidth }
        if barIndex > storyIndex { return 0 }
        return totalWidth * CGFloat(min(1.0, max(0.0, progress)))
    }

    // MARK: - UX helpers
    private func likeBurst() {
        HapticManager.shared.impact(style: .soft)
        showHeart = true
        heartScale = 0.6
        if reduceMotion {
            heartScale = 1.25
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showHeart = false
                heartScale = 0.6
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { heartScale = 1.25 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                showHeart = false
                heartScale = 0.6
            }
        }
    }

    // MARK: - Story Actions

    private func deleteCurrentStory() {
        guard let story = currentStory, let storyId = story.originalStoryId else {
            resume()
            return
        }
        isDeletingStory = true
        stopTimer()
        Task {
            do {
                try await DatabaseService.shared.deleteStory(id: storyId)
                HapticManager.shared.notification(type: .success)
                await MainActor.run {
                    isDeletingStory = false
                    // Advance to next or dismiss if no more stories
                    let groupCount = storiesInCurrentGroup
                    if groupCount > 1 && storyIndex < groupCount - 1 {
                        nextStory()
                    } else {
                        onDismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isDeletingStory = false
                    resume()
                    print("❌ [Stories] Delete failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func archiveCurrentStory() {
        guard let story = currentStory, let storyId = story.originalStoryId else {
            resume()
            return
        }
        Task {
            try? await DatabaseService.shared.archiveStory(id: storyId)
            await MainActor.run {
                HapticManager.shared.notification(type: .success)
                nextStory()
            }
        }
    }

    private func saveCurrentStoryToPhotos() {
        guard let story = currentStory else { resume(); return }
        Task {
            switch story.media {
            case .image(let urlString):
                guard let url = URL(string: urlString),
                      let data = try? Data(contentsOf: url),
                      let image = UIImage(data: data) else {
                    await MainActor.run { resume() }
                    return
                }
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                await MainActor.run {
                    HapticManager.shared.notification(type: .success)
                    resume()
                }
            case .video(let urlString):
                guard let url = URL(string: urlString) else {
                    await MainActor.run { resume() }
                    return
                }
                UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
                await MainActor.run {
                    HapticManager.shared.notification(type: .success)
                    resume()
                }
            default:
                await MainActor.run { resume() }
            }
        }
    }
}

#Preview("Asset Stories Pager") {
    AssetStoriesPagerView(
        stories: AssetStory.sampleStories,
        initialIndex: 0,
        onDismiss: {}
    )
}