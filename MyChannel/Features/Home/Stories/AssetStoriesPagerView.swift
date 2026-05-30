import SwiftUI
import AVKit
import AVFoundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct StoryProfilePresentation: Identifiable {
    let id: String
    let user: User
}

struct StoryInsightsSnapshot {
    let views: Int
    let likes: Int
    let replies: Int
    let shares: Int
}

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
    @State private var showingReplyComposer: Bool = false
    @State private var replyText: String = ""
    @State private var showingReportSheet: Bool = false
    @State private var showingShareSheet: Bool = false
    @State private var presentedProfile: StoryProfilePresentation?
    @State private var isSubmittingReply: Bool = false
    @State private var isLikingStory: Bool = false
    @State private var currentPlayer: AVPlayer?
    @State private var currentVideoDuration: TimeInterval?
    @State private var playerEndObserver: NSObjectProtocol?
    @State private var showingInsightsSheet: Bool = false
    @State private var storyInsights = StoryInsightsSnapshot(views: 0, likes: 0, replies: 0, shares: 0)
    @State private var showingArchiveSheet: Bool = false
    @State private var showingHighlightPrompt: Bool = false
    @State private var highlightTitle: String = "Favorites"
    @State private var archivedStories: [Story] = []

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

    private func configurePlaybackForCurrentStory() {
        tearDownPlayer()
        currentVideoDuration = nil

        guard let story = currentStory else { return }

        switch story.media {
        case .image:
            break
        case .video(let resource):
            guard let url = resolvedMediaURL(from: resource) else { return }
            let playerItem = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: playerItem)
            player.actionAtItemEnd = .pause
            currentPlayer = player

            Task {
                let duration = await loadVideoDuration(from: playerItem)
                await MainActor.run {
                    if currentStory?.stableStoryId == story.stableStoryId {
                        currentVideoDuration = duration
                        resetProgress()
                        if !isPaused {
                            currentPlayer?.play()
                        }
                    }
                }
            }

            playerEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { _ in
                nextStory()
            }

            if !isPaused {
                player.play()
            }
        }
    }

    private func tearDownPlayer() {
        if let observer = playerEndObserver {
            NotificationCenter.default.removeObserver(observer)
            playerEndObserver = nil
        }
        currentPlayer?.pause()
        currentPlayer = nil
    }

    private func resolvedMediaURL(from resource: String) -> URL? {
        if let remoteURL = URL(string: resource), let scheme = remoteURL.scheme, scheme == "https" || scheme == "http" {
            return remoteURL
        }
        return Bundle.main.url(forResource: resource, withExtension: nil)
    }

    private func loadVideoDuration(from item: AVPlayerItem) async -> TimeInterval {
        let asset = item.asset
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            if seconds.isFinite, seconds > 0 {
                return seconds
            }
        } catch {
            print("⚠️ [AssetStoriesPagerView] Failed to load video duration: \(error.localizedDescription)")
        }
        return videoDuration
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
                        Task {
                            await toggleLike()
                        }
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
                markCurrentStorySeen()
                Task {
                    if let userId = appState.currentUser?.id {
                        await StoryActionService.shared.loadLikeState(userId: userId)
                    }
                }
                configurePlaybackForCurrentStory()
                startTimer()
            }
            .onDisappear {
                stopTimer()
                tearDownPlayer()
            }
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
        .onChange(of: userIndex) { _ in
            configurePlaybackForCurrentStory()
        }
        .onChange(of: storyIndex) { _ in
            configurePlaybackForCurrentStory()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let story = currentStory {
                NativeShareSheet(
                    items: [storyShareText(for: story)],
                    onComplete: { completed in
                        Task {
                            await trackShareCompletion(completed: completed)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingReportSheet) {
            if let story = currentStory {
                ReportStoryView(story: storyModel(from: story)) {
                    showingReportSheet = false
                    resume()
                }
            }
        }
        .sheet(isPresented: $showingInsightsSheet, onDismiss: {
            resume()
        }) {
            StoryInsightsSheet(insights: storyInsights)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingArchiveSheet, onDismiss: {
            resume()
        }) {
            StoryArchiveView(stories: archivedStories) { story in
                highlightTitle = "Favorites"
                Task {
                    await StoryHighlightsService.shared.addStoryToHighlight(story: story, title: highlightTitle)
                }
            }
        }
        .sheet(isPresented: $showingReplyComposer) {
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 42, height: 5)
                    .padding(.top, 10)

                HStack {
                    storyAvatar(for: currentGroup)
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())

                    Text("Reply to \(currentGroup?.username ?? "story")")
                        .font(.headline)

                    Spacer()
                }

                TextField("Send message", text: $replyText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    Task {
                        await sendReply()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isSubmittingReply {
                            ProgressView()
                                .tint(.white)
                        }

                        Text("Send")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingReply ? Color.gray.opacity(0.35) : AppTheme.Colors.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingReply)

                Spacer()
            }
            .padding(.horizontal, 18)
            .presentationDetents([.height(240)])
            .presentationDragIndicator(.hidden)
            .onDisappear {
                if showingReplyComposer == false {
                    resume()
                }
            }
        }
        .sheet(item: $presentedProfile) { presentation in
            NavigationStack {
                PublicProfileView(user: presentation.user)
                    .environmentObject(AuthenticationManager.shared)
                    .environmentObject(appState)
            }
        }
        .alert("Add to Highlight", isPresented: $showingHighlightPrompt) {
            TextField("Highlight title", text: $highlightTitle)
            Button("Save") {
                Task {
                    if let story = currentStory {
                        await StoryHighlightsService.shared.addStoryToHighlight(story: storyModel(from: story), title: highlightTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Favorites" : highlightTitle)
                        HapticManager.shared.notification(type: .success)
                        resume()
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                resume()
            }
        } message: {
            Text("Save this story to one of your profile highlights.")
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
            if let currentPlayer {
                RawPlayerLayerView(player: currentPlayer, videoGravity: .resizeAspectFill)
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
            HStack(spacing: 8) {
                storyAvatar(for: currentGroup)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .onTapGesture {
                        Task {
                            await openCurrentProfile()
                        }
                    }
                HStack(spacing: 4) {
                    Text(currentGroup?.username ?? "")
                        .foregroundStyle(.white)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text("14h")
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.system(size: 14, weight: .medium))
                }
                .onTapGesture {
                    Task {
                        await openCurrentProfile()
                    }
                }
            }
            Spacer()
            HStack(spacing: 16) {
                if currentStory?.creatorId == appState.currentUser?.id {
                    Button {
                        pause()
                        Task {
                            await loadCurrentStoryInsights()
                            showingInsightsSheet = true
                        }
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                }

                Button {
                    HapticManager.shared.selection()
                    pause()
                    showStoryOptions = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
                .confirmationDialog("", isPresented: $showStoryOptions, titleVisibility: .hidden) {
                    let isOwner = currentStory?.creatorId == appState.currentUser?.id
                    if isOwner {
                        Button("Add to Highlight") {
                            highlightTitle = currentGroup?.username ?? "Favorites"
                            showingHighlightPrompt = true
                        }
                        Button("View Archive") {
                            Task {
                                await loadArchivedStories()
                                showingArchiveSheet = true
                            }
                        }
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
                        showingReportSheet = true
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
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 16) {
            HStack {
                Text("Send message")
                    .foregroundStyle(.white)
                    .font(.system(size: 14, weight: .regular))
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
            .contentShape(Capsule())
            .onTapGesture {
                pause()
                showingReplyComposer = true
            }

            Button {
                Task {
                    await toggleLike()
                }
            } label: {
                Image(systemName: showHeart ? "heart.fill" : "heart")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(showHeart ? .red : .white)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }

            Button {
                HapticManager.shared.selection()
                pause()
                showingShareSheet = true
            } label: {
                Image(systemName: "paperplane")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2)
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
        case .video: return currentVideoDuration ?? videoDuration
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
        currentPlayer?.pause()
        if reduceMotion {
            isPaused = true
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isPaused = true }
        }
    }

    private func resume() {
        if case .video? = currentStory?.media {
            currentPlayer?.play()
        }
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
            markCurrentStorySeen()
            transitionDirection = 1
            if reduceMotion {
                storyIndex += 1
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { storyIndex += 1 }
            }
            HapticManager.shared.selection()
            resetProgress()
            markCurrentStorySeen()
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
            markCurrentStorySeen()
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
            markCurrentStorySeen()
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
            markCurrentStorySeen()
        } else {
            onDismiss()
        }
    }

    /// Mark the current user's stories as seen
    private func markCurrentUserSeen() {
        guard let group = currentGroup else { return }
        let userId = AppState.shared.currentUser?.id ?? "anonymous"
        for story in group.stories {
            StorySeenTracker.shared.markSeen(userId: userId, storyId: story.stableStoryId, creatorId: story.creatorId.isEmpty ? group.username : story.creatorId)
        }
    }

    private func markCurrentStorySeen() {
        guard let story = currentStory else { return }
        let userId = AppState.shared.currentUser?.id ?? "anonymous"
        StorySeenTracker.shared.markSeen(userId: userId, storyId: story.stableStoryId, creatorId: story.creatorId)
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
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                showHeart = false
                heartScale = 0.6
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { heartScale = 1.25 }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                showHeart = false
                heartScale = 0.6
            }
        }
    }

    private func toggleLike() async {
        guard let story = currentStory,
              let userId = appState.currentUser?.id,
              !isLikingStory else { return }
        isLikingStory = true
        let didLike = await StoryActionService.shared.toggleLike(storyId: story.stableStoryId, creatorId: story.creatorId, userId: userId)
        await MainActor.run {
            if didLike {
                likeBurst()
            } else {
                showHeart = false
                heartScale = 0.6
                HapticManager.shared.selection()
            }
            isLikingStory = false
        }
    }

    private func sendReply() async {
        guard let story = currentStory,
              let userId = appState.currentUser?.id else { return }
        let pendingReply = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pendingReply.isEmpty else { return }

        isSubmittingReply = true
        do {
            try await StoryActionService.shared.sendReply(storyId: story.stableStoryId, creatorId: story.creatorId, userId: userId, text: pendingReply)
            await MainActor.run {
                HapticManager.shared.notification(type: .success)
                replyText = ""
                showingReplyComposer = false
                isSubmittingReply = false
                resume()
            }
        } catch {
            await MainActor.run {
                print("🚨 [AssetStoriesPagerView] Failed to send reply: \(error.localizedDescription)")
                isSubmittingReply = false
            }
        }
    }

    private func trackShareCompletion(completed: Bool) async {
        guard let story = currentStory,
              let userId = appState.currentUser?.id else {
            await MainActor.run { resume() }
            return
        }
        await StoryActionService.shared.trackShare(storyId: story.stableStoryId, creatorId: story.creatorId, userId: userId, completed: completed)
        await MainActor.run {
            resume()
        }
    }

    private func openCurrentProfile() async {
        guard let story = currentStory else { return }
        pause()
        if let user = try? await UserFirestoreService.shared.fetchUser(id: story.creatorId) {
            await MainActor.run {
                presentedProfile = StoryProfilePresentation(id: user.id, user: user)
            }
        } else {
            await MainActor.run {
                resume()
            }
        }
    }

    private func storyShareText(for story: AssetStory) -> String {
        let username = currentGroup?.username ?? story.username
        return "Check out @\(username)'s story on MyChannel! https://mychannel.app/stories/\(story.stableStoryId)"
    }

    private func storyModel(from story: AssetStory) -> Story {
        Story(
            id: story.stableStoryId,
            creatorId: story.creatorId,
            mediaURL: story.media.primaryURL,
            mediaType: story.media.storyMediaType,
            duration: durationForCurrent(),
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(86400)
        )
    }

    private func loadCurrentStoryInsights() async {
        guard let story = currentStory else { return }

        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let storyDoc = try await db.collection("stories").document(story.stableStoryId).getDocument()
            let data = storyDoc.data() ?? [:]
            let likes = data["likeCount"] as? Int ?? 0
            let replies = data["replyCount"] as? Int ?? data["commentCount"] as? Int ?? 0
            let shares = data["shareCount"] as? Int ?? 0
            let views = data["viewCount"] as? Int ?? StoryViewTracker.shared.viewerCount

            await MainActor.run {
                storyInsights = StoryInsightsSnapshot(views: views, likes: likes, replies: replies, shares: shares)
            }
        } catch {
            await MainActor.run {
                storyInsights = StoryInsightsSnapshot(
                    views: StoryViewTracker.shared.viewerCount,
                    likes: 0,
                    replies: 0,
                    shares: 0
                )
            }
        }
        #else
        await MainActor.run {
            storyInsights = StoryInsightsSnapshot(
                views: StoryViewTracker.shared.viewerCount,
                likes: 0,
                replies: 0,
                shares: 0
            )
        }
        #endif
    }

    private func loadArchivedStories() async {
        guard let creatorId = appState.currentUser?.id else { return }
        if let stories = try? await DatabaseService.shared.fetchStoriesByCreator(creatorId: creatorId, includeExpired: true) {
            await MainActor.run {
                archivedStories = stories.filter { $0.isExpired }
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

private extension AssetMedia {
    var primaryURL: String {
        switch self {
        case .image(let value):
            return value
        case .video(let value):
            return value
        }
    }

    var storyMediaType: Story.MediaType {
        switch self {
        case .image:
            return .image
        case .video:
            return .video
        }
    }
}

private struct StoryInsightsSheet: View {
    let insights: StoryInsightsSnapshot

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 42, height: 5)
                .padding(.top, 10)

            Text("Story insights")
                .font(.headline)

            HStack(spacing: 12) {
                insightCard(title: "Views", value: insights.views, icon: "eye.fill")
                insightCard(title: "Likes", value: insights.likes, icon: "heart.fill")
            }

            HStack(spacing: 12) {
                insightCard(title: "Replies", value: insights.replies, icon: "bubble.left.fill")
                insightCard(title: "Shares", value: insights.shares, icon: "paperplane.fill")
            }

            Spacer()
        }
        .padding(.horizontal, 18)
    }

    private func insightCard(title: String, value: Int, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primary)

            Text("\(value)")
                .font(.system(size: 22, weight: .bold))

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview("Asset Stories Pager") {
    AssetStoriesPagerView(
        stories: AssetStory.sampleStories,
        initialIndex: 0,
        onDismiss: {}
    )
}