import SwiftUI
import AVKit
import AVFoundation

struct AdPlayerOverlay: View {
    let adUrl: String
    let onFinish: () -> Void
    @State private var adPlayer = AVPlayer()
    @State private var isReady = false
    @State private var isPlaying = false
    @State private var impressionId: String?
    @State private var playerItemObserver: NSKeyValueObservation?

    var body: some View {
        ZStack {
            RawPlayerLayerView(player: adPlayer, videoGravity: .resizeAspect)
                .background(ViewabilityTrackingView { view in
                    // Start OMID tracking when view appears
                    if impressionId == nil {
                        impressionId = OMIDViewabilityService.shared.startImpression(adId: adUrl, adView: view)
                    }
                })
                .onAppear { play() }

            if !isReady {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.3)
                    Text("Loading ad...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            VStack {
                HStack {
                    Text("Ad").font(.caption.weight(.semibold)).foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(12)
                Spacer()
            }
        }
        .background(Color.black)
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: adPlayer.currentItem)) { _ in
            print("✅ [AdPlayerOverlay] Ad finished playing")
            if let id = impressionId {
                let _ = OMIDViewabilityService.shared.endImpression(impressionId: id)
            }
            onFinish()
        }
        .onDisappear {
            print("👋 [AdPlayerOverlay] View disappearing")
            playerItemObserver?.invalidate()
            playerItemObserver = nil
            adPlayer.pause()
            if let id = impressionId {
                let _ = OMIDViewabilityService.shared.endImpression(impressionId: id)
            }
        }
    }

    private func play() {
        print("▶️ [AdPlayerOverlay] play() called with URL: \(adUrl)")
        
        // 🔥 FIX: Check if URL is a VAST tag (XML) or a direct video URL
        let isVASTTag = adUrl.contains("doubleclick.net") || 
                        adUrl.contains("googleads") || 
                        adUrl.contains("vast") ||
                        adUrl.contains("output=vast")
        
        if isVASTTag {
            print("📺 [AdPlayerOverlay] Detected VAST tag URL - fetching actual video URL")
            Task {
                if let videoUrl = await fetchVideoURLFromVAST(adUrl) {
                    await MainActor.run {
                        playVideoURL(videoUrl)
                    }
                } else {
                    print("❌ [AdPlayerOverlay] Failed to get video URL from VAST")
                    await MainActor.run {
                        // Fallback to a test ad
                        playVideoURL("https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4")
                    }
                }
            }
        } else {
            playVideoURL(adUrl)
        }
    }
    
    private func fetchVideoURLFromVAST(_ vastUrl: String) async -> String? {
        guard let url = URL(string: vastUrl) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let vastString = String(data: data, encoding: .utf8) ?? ""
            
            // Extract MediaFile URL from VAST XML
            if let mediaURL = extractMediaFile(from: vastString) {
                print("✅ [AdPlayerOverlay] Extracted media URL: \(mediaURL)")
                return mediaURL
            }
        } catch {
            print("❌ [AdPlayerOverlay] Failed to fetch VAST: \(error)")
        }
        
        return nil
    }
    
    private func extractMediaFile(from vast: String) -> String? {
        // Pattern to match MediaFile content
        let pattern = #"<MediaFile[^>]*>(.*?)</MediaFile>"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: vast, range: NSRange(vast.startIndex..., in: vast)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: vast) else {
            return nil
        }
        
        var url = String(vast[range])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "<![CDATA[", with: "")
            .replacingOccurrences(of: "]]>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Make sure URL is valid
        if URL(string: url) != nil {
            return url
        }
        
        return nil
    }
    
    private func playVideoURL(_ urlString: String) {
        print("▶️ [AdPlayerOverlay] Playing video URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ [AdPlayerOverlay] Invalid URL: \(urlString)")
            onFinish()
            return
        }
        
        // 🔥 FIX: Configure audio session FIRST for video playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ [AdPlayerOverlay] Audio session configured")
        } catch {
            print("⚠️ [AdPlayerOverlay] Audio session error: \(error)")
        }
        
        // Create asset and player item
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        // 🔥 FIX: Observe player item status to know when it's ready
        playerItemObserver = item.observe(\.status, options: [.new, .initial]) { [self] playerItem, _ in
            DispatchQueue.main.async {
                switch playerItem.status {
                case .readyToPlay:
                    print("✅ [AdPlayerOverlay] Player item ready to play!")
                    self.isReady = true
                    if !self.isPlaying {
                        self.isPlaying = true
                        self.adPlayer.play()
                        print("▶️ [AdPlayerOverlay] Started playback - rate: \(self.adPlayer.rate)")
                    }
                case .failed:
                    print("❌ [AdPlayerOverlay] Player item failed: \(playerItem.error?.localizedDescription ?? "unknown")")
                    self.isReady = true  // Hide loading even on error
                    self.onFinish()
                case .unknown:
                    print("⏳ [AdPlayerOverlay] Player item status unknown (loading...)")
                @unknown default:
                    break
                }
            }
        }
        
        // Replace current item and configure player
        adPlayer.replaceCurrentItem(with: item)
        adPlayer.volume = 1.0
        adPlayer.isMuted = false
        
        // 🔥 FIX: Also try to play immediately (will work if already ready)
        adPlayer.play()
        print("▶️ [AdPlayerOverlay] Called play() on player - rate: \(adPlayer.rate)")
    }
}

struct ViewabilityTrackingView: UIViewRepresentable {
    let onViewReady: (UIView) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            onViewReady(view)
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}


