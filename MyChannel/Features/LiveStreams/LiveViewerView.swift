//
//  LiveViewerView.swift
//  MyChannel
//
//  Viewer screen for watching a live stream.
//  Shows creator info, LIVE badge, viewer count, live chat, and interaction buttons.
//

import SwiftUI
import AVKit

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif
import MapKit

struct LiveViewerView: View {
    let stream: FirestoreLiveStream

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var liveManager = LiveStreamManager.shared
    @StateObject private var locationEngine = LiveLocationEngine.shared
    @StateObject private var captionsService = LiveCaptionsService.shared

    @State private var chatMessages: [(id: String, username: String, content: String, avatar: String)] = []
    @State private var chatText = ""
    @State private var isLiked = false
    @State private var streamEnded = false
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?
    @State private var player: AVPlayer?
    @State private var currentPlaybackURL: String? = nil

    #if canImport(FirebaseFirestore)
    @State private var streamListener: ListenerRegistration?
    #endif
    #if canImport(FirebaseDatabase)
    @State private var chatQuery: DatabaseQuery?
    @State private var chatHandle: DatabaseHandle?
    #endif

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top nav
                topBar

                if streamEnded {
                    streamEndedView
                } else {
                    // Stream video / preview area
                    streamPreviewArea

                    // Stream info
                    streamInfoBar

                    // Chat area
                    chatArea
                }
            }

            // Live captions overlay (bottom of video area)
            if AppConfig.Features.enableLiveCaptions && captionsService.isEnabled
                && !captionsService.captions.isEmpty {
                VStack {
                    Spacer()
                        .frame(height: 56) // below topBar
                    ZStack(alignment: .bottom) {
                        Spacer()
                        VStack(spacing: 4) {
                            ForEach(captionsService.captions.suffix(3)) { caption in
                                Text(caption.text)
                                    .font(.system(size: captionsService.fontSize, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.black.opacity(caption.isFinal ? 0.75 : 0.5))
                                    )
                                    .opacity(caption.isFinal ? 1.0 : 0.8)
                            }
                        }
                        .padding(.bottom, 280) // above chat overlay
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                    }
                    Spacer()
                }
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: captionsService.captions.count)
            }
        }
        .statusBarHidden()
        .onAppear {
            startTimer()
            Task {
                await liveManager.joinAsViewer(streamId: stream.id)
            }
            startChatListener()
            startStreamStatusListener()
            locationEngine.listenToStreamerLocation(streamId: stream.id)
            setupPlayerIfNeeded(url: stream.playbackURL)
            if AppConfig.Features.enableLiveCaptions {
                captionsService.startCaptioning()
            }
        }
        .onDisappear {
            stopTimer()
            Task {
                await liveManager.leaveAsViewer(streamId: stream.id)
            }
            stopListeners()
            locationEngine.stopListening()
            player?.pause()
            player = nil
            captionsService.stopCaptioning()
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            Spacer()

            // Captions toggle (CC)
            if AppConfig.Features.enableLiveCaptions {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if captionsService.isEnabled {
                            captionsService.stopCaptioning()
                        } else {
                            captionsService.startCaptioning()
                        }
                    }
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: captionsService.isEnabled ? "captions.bubble.fill" : "captions.bubble")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(captionsService.isEnabled ? AppTheme.Colors.primary : .white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
            }

            // Share
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Stream Preview Area
    private var streamPreviewArea: some View {
        ZStack {
            Color.black

            if player != nil {
                // Real HLS/RTMP playback
                VideoPlayer(player: player!)
                    .frame(height: 280)
                    .onAppear { player?.play() }
            } else {
                // Fallback: avatar + pulsing LIVE badge while stream URL loads
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.1, blue: 0.15), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.red, lineWidth: 3)
                            .frame(width: 90, height: 90)
                            .scaleEffect(pulseScale)
                            .opacity(pulseOpacity)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseScale)

                        if !stream.creatorAvatar.isEmpty, let url = URL(string: stream.creatorAvatar) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                avatarPlaceholder
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            avatarPlaceholder
                        }
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("LIVE")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(6)

                    Text(stream.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 32)
                }
            }

            // IRL Mini Map Overlay
            if let coordinate = locationEngine.streamerLocation {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Map(position: .constant(.region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))))) {
                            Marker(stream.creatorName, coordinate: coordinate)
                                .tint(.red)
                        }
                        .frame(width: 120, height: 120)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .padding(12)
                    }
                }
            }

            // LIVE badge overlay when video is playing
            if player != nil {
                VStack {
                    HStack {
                        HStack(spacing: 5) {
                            Circle().fill(.red).frame(width: 7, height: 7)
                            Text("LIVE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(4)
                        Spacer()
                    }
                    .padding(8)
                    Spacer()
                }
            }
        }
        .frame(height: 280)
    }

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.4))
            .frame(width: 80, height: 80)
            .overlay(
                Text(String(stream.creatorName.prefix(1)).uppercased())
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    // MARK: - Stream Info Bar
    private var streamInfoBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(stream.creatorName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    if stream.creatorIsVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 11))
                        Text("\(liveManager.viewerCount(for: stream.id, fallback: stream.viewerCount)) watching")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white.opacity(0.7))

                    Text(formattedDuration)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            Button {
                isLiked.toggle()
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 22))
                    .foregroundColor(isLiked ? .red : .white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }

    // MARK: - Chat Area
    private var chatArea: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(chatMessages, id: \.id) { msg in
                            HStack(alignment: .top, spacing: 8) {
                                if !msg.avatar.isEmpty, let url = URL(string: msg.avatar) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle().fill(Color.gray.opacity(0.3))
                                    }
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Text(String(msg.username.prefix(1)).uppercased())
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(msg.username)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.blue)
                                    Text(msg.content)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .onChange(of: chatMessages.count) { _ in
                    if let last = chatMessages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            if stream.enableChat {
                HStack(spacing: 8) {
                    TextField("Say something…", text: $chatText)
                        .font(.system(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                        .foregroundColor(.white)

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                    .disabled(chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black)
            }
        }
        .background(Color(white: 0.08))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
                pulseOpacity = 0.3
            }
        }
    }

    // MARK: - Stream Ended View
    private var streamEndedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "tv.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.4))
            Text("Stream Ended")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            Text("\(stream.creatorName)'s live stream has ended.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("Back to Home")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .cornerRadius(24)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    // MARK: - Player Setup
    private func setupPlayerIfNeeded(url: String?) {
        guard let urlString = url, !urlString.isEmpty, let streamURL = URL(string: urlString) else { return }
        guard currentPlaybackURL != urlString else { return }
        currentPlaybackURL = urlString
        let item = AVPlayerItem(url: streamURL)
        if let existing = player {
            existing.replaceCurrentItem(with: item)
        } else {
            player = AVPlayer(playerItem: item)
        }
        player?.play()
    }

    // MARK: - Helpers
    private var formattedDuration: String {
        let total = Date().timeIntervalSince(stream.startedAt)
        let h = Int(total) / 3600
        let m = (Int(total) % 3600) / 60
        let s = Int(total) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                elapsed += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func sendMessage() {
        let content = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        Task {
            await liveManager.sendChatMessage(streamId: stream.id, content: content)
            chatText = ""
        }
    }

    // MARK: - Realtime Listeners
    private func startChatListener() {
        #if canImport(FirebaseDatabase)
        let query = Database.database().reference()
            .child("live_chat").child(stream.id).child("messages")
            .queryOrdered(byChild: "timestamp")
            .queryLimited(toLast: 100)
        chatQuery = query
        chatHandle = query.observe(.value) { snapshot in
            let messages: [(id: String, username: String, content: String, avatar: String)] =
                snapshot.children.allObjects.compactMap { child in
                    guard let message = child as? DataSnapshot,
                          let data = message.value as? [String: Any],
                          let content = data["text"] as? String,
                          !content.isEmpty else {
                        return nil
                    }
                    return (
                        id: message.key,
                        username: data["displayName"] as? String ?? "Viewer",
                        content: content,
                        avatar: ""
                    )
                }
            Task { @MainActor in
                chatMessages = messages
            }
        }
        #else
        chatMessages = [
            (id: "1", username: "Fan1", content: "🔥 This is fire!", avatar: ""),
            (id: "2", username: "Viewer42", content: "Hey everyone!", avatar: ""),
            (id: "3", username: "MusicLover", content: "Let's gooo 🎉", avatar: ""),
        ]
        #endif
    }

    private func startStreamStatusListener() {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        streamListener = db.collection("live_streams").document(stream.id)
            .addSnapshotListener { snapshot, _ in
                guard let data = snapshot?.data() else { return }
                let status = data["status"] as? String ?? "live"
                let updatedPlaybackURL = data["playbackURL"] as? String
                Task { @MainActor in
                    if status == "ended" {
                        streamEnded = true
                        player?.pause()
                    } else if let url = updatedPlaybackURL {
                        setupPlayerIfNeeded(url: url)
                    }
                }
            }
        #endif
    }

    private func stopListeners() {
        #if canImport(FirebaseDatabase)
        if let chatQuery, let chatHandle {
            chatQuery.removeObserver(withHandle: chatHandle)
        }
        self.chatQuery = nil
        self.chatHandle = nil
        #endif
        #if canImport(FirebaseFirestore)
        streamListener?.remove()
        streamListener = nil
        #endif
    }
}

#Preview("Live Viewer") {
    LiveViewerView(stream: LiveStreamManager.sampleStreams[0])
}
