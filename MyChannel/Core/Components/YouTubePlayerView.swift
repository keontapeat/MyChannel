import SwiftUI
import WebKit
import AVFoundation

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    var autoplay: Bool = true
    var startTime: Int = 0
    var muted: Bool = false
    var showControls: Bool = true
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        
        let auto = autoplay ? "1" : "0"
        let controls = showControls ? "1" : "0"
        let fs = "0"
        let mute = muted ? "1" : "0"
        let loop = "1"
        let start = max(0, startTime)
        let urlString =
        "https://www.youtube-nocookie.com/embed/\(videoID)?playsinline=1&autoplay=\(auto)&rel=0&controls=\(controls)&fs=\(fs)&modestbranding=1&color=white&mute=\(mute)&loop=\(loop)&playlist=\(videoID)&start=\(start)&enablejsapi=1&origin=https://www.youtube.com"
        
        if let url = URL(string: urlString) {
            if webView.url?.absoluteString != url.absoluteString {
                webView.load(URLRequest(url: url))
            } else {
                context.coordinator.autoplayAndEnsureAudioIfNeeded()
            }
        }
    }
    
    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: YouTubePlayerView
        weak var webView: WKWebView?
        private static var didActivateAudioSession = false
        
        private var shouldAutoEnableAudio: Bool {
            parent.autoplay && parent.showControls
        }
        
        init(_ parent: YouTubePlayerView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            autoplayAndEnsureAudioIfNeeded()
        }
        
        private func ensureAudioSessionActive() {
            guard !Self.didActivateAudioSession else { return }
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
                Self.didActivateAudioSession = true
            } catch {
                print("AudioSession activation failed: \(error)")
            }
        }
        
        func autoplayAndEnsureAudioIfNeeded() {
            guard let webView else { return }
            
            if shouldAutoEnableAudio {
                ensureAudioSessionActive()
            }
            
            let playJS = "window.postMessage(JSON.stringify({'event':'command','func':'playVideo','args':[]}), '*');"
            webView.evaluateJavaScript(playJS, completionHandler: nil)
            
            if shouldAutoEnableAudio {
                let attempts = 6
                for i in 0..<attempts {
                    let delay = 0.15 + (0.2 * Double(i))
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak webView] in
                        let unmuteJS =
                        """
                        window.postMessage(JSON.stringify({'event':'command','func':'unMute','args':[]}), '*');
                        window.postMessage(JSON.stringify({'event':'command','func':'setVolume','args':[100]}), '*');
                        window.postMessage(JSON.stringify({'event':'command','func':'playVideo','args':[]}), '*');
                        """
                        webView?.evaluateJavaScript(unmuteJS, completionHandler: nil)
                    }
                }
            }
        }
    }
}

#Preview("YouTubePlayerView - Trailer (Autoplay with Audio)") {
    // Trailer-style: controls visible, will autoplay then enable audio
    YouTubePlayerView(videoID: "dQw4w9WgXcQ", autoplay: true, startTime: 0, muted: true, showControls: true)
        .frame(height: 260)
        .background(Color.black)
        .preferredColorScheme(.dark)
}

#Preview("YouTubePlayerView - Shorts (Muted Autoplay)") {
    // Shorts-style: controls hidden, stays muted
    YouTubePlayerView(videoID: "dQw4w9WgXcQ", autoplay: true, startTime: 0, muted: true, showControls: false)
        .frame(height: 260)
        .background(Color.black)
        .preferredColorScheme(.dark)
}