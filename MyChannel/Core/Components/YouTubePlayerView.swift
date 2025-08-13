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
        let urlString = "https://www.youtube-nocookie.com/embed/\(videoID)?playsinline=1&autoplay=\(auto)&rel=0&modestbranding=1&color=white&showinfo=0&start=\(startTime)"
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }
}

#Preview("YouTubePlayerView") {
    YouTubePlayerView(videoID: "dQw4w9WgXcQ")
        .frame(height: 300)
        .background(Color.black)
        .preferredColorScheme(.dark)
}