import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    var autoplay: Bool = true
    var startTime: Int = 0
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let auto = autoplay ? "1" : "0"
        // Full YouTube player with fullscreen button and standard UI
        let urlString =
        "https://www.youtube-nocookie.com/embed/\(videoID)?playsinline=1&autoplay=\(auto)&rel=0&controls=1&fs=1&modestbranding=1&color=white&start=\(startTime)"
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }
}

#Preview("YouTubePlayerView - Fullscreen UI") {
    YouTubePlayerView(videoID: "dQw4w9WgXcQ", autoplay: false)
        .frame(height: 300)
        .background(Color.black)
        .preferredColorScheme(.dark)
}