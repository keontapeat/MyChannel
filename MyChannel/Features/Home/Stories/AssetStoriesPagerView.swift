import SwiftUI
import AVKit

struct AssetStoriesPagerView: View {
    let stories: [AssetStory]
    let initialIndex: Int
    let onDismiss: () -> Void
    
    @State private var index: Int
    @State private var progress: Double = 0
    @State private var isPaused: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var timer: Timer?
    
    private let imageDuration: TimeInterval = 5.0
    private let videoDuration: TimeInterval = 8.0
    
    init(stories: [AssetStory], initialIndex: Int = 0, onDismiss: @escaping () -> Void) {
        self.stories = stories
        self.initialIndex = min(max(0, initialIndex), stories.count - 1)
        self.onDismiss = onDismiss
        _index = State(initialValue: self.initialIndex)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                
                currentContent
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .scaleEffect(isPaused ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.25), value: isPaused)
                
                // Top overlays: progress + header
                VStack(spacing: 10) {
                    HStack(spacing: 4) {
                        ForEach(0..<stories.count, id: \.self) { i in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.25))
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: fillWidth(for: i, totalWidth: (UIScreen.main.bounds.width - 16 - CGFloat(stories.count - 1) * 4) / CGFloat(stories.count)))
                                    .animation(.linear(duration: 0.05), value: progress)
                            }
                            .frame(height: 3)
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    HStack {
                        HStack(spacing: 10) {
                            storyAvatar(for: stories[index])
                                .frame(width: 34, height: 34)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            Text(stories[index].username)
                                .foregroundStyle(.white)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                        }
                        Spacer()
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
                    .padding(.horizontal, 12)
                }
                .padding(.top, 14)
                .frame(maxHeight: .infinity, alignment: .top)
                
                // Invisible tap regions
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            previous()
                        }
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            next()
                        }
                }
                .allowsHitTesting(true)
                
                // Pause indicator
                if isPaused {
                    Image(systemName: "pause.fill")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.35), in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        if value.translation.height > 120 {
                            HapticManager.shared.impact(style: .light)
                            onDismiss()
                            return
                        }
                        if value.translation.width < -80 {
                            next()
                        } else if value.translation.width > 80 {
                            previous()
                        }
                        dragOffset = .zero
                    }
            )
            .offset(dragOffset)
            .scaleEffect(dragOffset.height > 0 ? max(0.85, 1 - dragOffset.height / 900) : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: dragOffset)
            .onLongPressGesture(minimumDuration: 0.15) {
                pause()
            } onPressingChanged: { pressing in
                if !pressing { resume() }
            }
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
        }
        .statusBarHidden()
        .ignoresSafeArea()
    }
    
    private var currentContent: some View {
        Group {
            switch stories[index].media {
            case .image(let name):
                if let ui = UIImage(named: name) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .transition(.opacity.combined(with: .scale))
                } else {
                    AsyncImage(url: URL(string: "https://picsum.photos/600/1200?random=\(abs(stories[index].id.hashValue))")) { img in
                        img.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ZStack {
                            LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            ProgressView().tint(.white)
                        }
                    }
                }
            case .video(let resource):
                if let url = Bundle.main.url(forResource: resource, withExtension: nil) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .transition(.opacity)
                } else {
                    ZStack {
                        LinearGradient(colors: [.purple.opacity(0.7), .blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        VStack(spacing: 12) {
                            Image(systemName: "play.circle.fill").font(.system(size: 72)).foregroundStyle(.white)
                            Text("Video not found").foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
            }
        }
        .onChange(of: stories[index].media) { _, _ in
            resetProgress()
        }
    }
    
    private func storyAvatar(for story: AssetStory) -> some View {
        Group {
            if let img = UIImage(named: story.authorImageName) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                AsyncImage(url: URL(string: "https://picsum.photos/200/200?random=\(abs(story.id.hashValue))")) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default:
                        Circle().fill(Color.white.opacity(0.25))
                            .overlay(Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.8)))
                    }
                }
            }
        }
    }
    
    private func durationForCurrent() -> TimeInterval {
        switch stories[index].media {
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
            if progress >= 1.0 {
                next()
            }
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isPaused = true
        }
    }
    
    private func resume() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isPaused = false
        }
    }
    
    private func next() {
        if index < stories.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                index += 1
            }
            HapticManager.shared.selection()
            resetProgress()
        } else {
            onDismiss()
        }
    }
    
    private func previous() {
        if index > 0 {
            withAnimation(.easeInOut(duration: 0.25)) {
                index -= 1
            }
            HapticManager.shared.selection()
            resetProgress()
        } else {
            // If first, a left tap could dismiss
            onDismiss()
        }
    }
    
    private func fillWidth(for barIndex: Int, totalWidth: CGFloat) -> CGFloat {
        if barIndex < index { return totalWidth }
        if barIndex > index { return 0 }
        return totalWidth * CGFloat(min(1.0, max(0.0, progress)))
    }
}

#Preview("Asset Stories Pager") {
    AssetStoriesPagerView(
        stories: AssetStory.sampleStories,
        initialIndex: 2,
        onDismiss: {}
    )
}