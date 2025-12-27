//
//  VideoPreviewOverlay.swift
//  MyChannel
//
//  Video preview on long-press - shows a quick preview of the video
//

import SwiftUI
import AVFoundation

// MARK: - Video Preview Overlay (Long Press)
struct VideoPreviewOverlay: View {
    let video: Video
    let isPresented: Bool
    let onDismiss: () -> Void
    let onPlay: () -> Void
    
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Blur Background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .opacity(opacity)
                .onTapGesture {
                    dismiss()
                }
            
            // Preview Card
            VStack(spacing: 0) {
                // Video Preview
                ZStack {
                    if let player = player {
                        SimpleAVPlayerView(player: player)
                            .aspectRatio(16/9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        // Thumbnail fallback
                        AppAsyncImage(url: URL(string: video.thumbnailURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle()
                                .fill(Color(.systemGray5))
                        }
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    // Loading indicator
                    if player == nil {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width - 40)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                
                // Video Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(video.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Text(video.creator.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("•")
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("\(video.formattedViewCount) views")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button {
                        HapticManager.shared.impact(style: .medium)
                        onPlay()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Watch Now")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.white))
                    }
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                }
                .padding(.top, 16)
            }
            .scaleEffect(opacity)
            .opacity(opacity)
        }
        .onChange(of: isPresented) { newValue in
            if newValue {
                show()
            } else {
                dismiss()
            }
        }
    }
    
    private func show() {
        HapticManager.shared.impact(style: .medium)
        
        // Start loading video
        loadVideoPreview()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            opacity = 1
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            opacity = 0
        }
        
        // Cleanup
        player?.pause()
        player = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
    
    private func loadVideoPreview() {
        guard let url = URL(string: video.videoURL) else { return }
        
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.isMuted = true
        newPlayer.play()
        
        // Auto-loop after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }
        
        player = newPlayer
    }
}

// MARK: - Simple AVPlayer View (for preview overlay)
private struct SimpleAVPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = PreviewPlayerUIView(player: player)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

private class PreviewPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    
    init(player: AVPlayer) {
        super.init(frame: .zero)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

// MARK: - Long Press Video Card Modifier
struct VideoLongPressModifier: ViewModifier {
    let video: Video
    let onPlay: (Video) -> Void
    
    @State private var showPreview = false
    
    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0.5) {
                showPreview = true
            }
            .fullScreenCover(isPresented: $showPreview) {
                VideoPreviewOverlay(
                    video: video,
                    isPresented: showPreview,
                    onDismiss: { showPreview = false },
                    onPlay: {
                        showPreview = false
                        onPlay(video)
                    }
                )
                .background(ClearBackgroundView())
            }
    }
}

// MARK: - Clear Background for Overlay
struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - View Extension
extension View {
    func videoLongPressPreview(video: Video, onPlay: @escaping (Video) -> Void) -> some View {
        modifier(VideoLongPressModifier(video: video, onPlay: onPlay))
    }
}

#Preview {
    VideoPreviewOverlay(
        video: Video.sampleVideos[0],
        isPresented: true,
        onDismiss: {},
        onPlay: {}
    )
}

