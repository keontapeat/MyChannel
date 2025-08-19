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
        let controller = WKUserContentController()
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false

        context.coordinator.webView = webView
        context.coordinator.loadHTMLIfNeeded(for: videoID,
                                             autoplay: autoplay,
                                             startTime: startTime,
                                             muted: muted,
                                             showControls: showControls)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self

        if context.coordinator.loadedVideoID != videoID {
            context.coordinator.loadHTMLIfNeeded(for: videoID,
                                                 autoplay: autoplay,
                                                 startTime: startTime,
                                                 muted: muted,
                                                 showControls: showControls)
            return
        }

        // Keep player state in sync without reloads
        let js = """
        (function(){
            if (window.player && window.player.getPlayerState) {
                \(muted ? "try{player.mute();}catch(e){}" : "try{player.unMute();}catch(e){}")
                \(autoplay ? "try{player.playVideo();}catch(e){}" : "try{player.pauseVideo();}catch(e){}")
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: YouTubePlayerView
        weak var webView: WKWebView?
        var loadedVideoID: String?

        init(_ parent: YouTubePlayerView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Ensure autoplay/mute applied when load completes
            let js = """
            (function(){
                if (window.player && window.player.getPlayerState) {
                    \(parent.muted ? "try{player.mute();}catch(e){}" : "try{player.unMute();}catch(e){}")
                    \(parent.autoplay ? "try{player.playVideo();}catch(e){}" : "")
                }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func loadHTMLIfNeeded(for videoID: String,
                              autoplay: Bool,
                              startTime: Int,
                              muted: Bool,
                              showControls: Bool) {
            guard let webView else { return }
            loadedVideoID = videoID

            ensureAudioSessionIfNeeded(autoplay: autoplay, muted: muted, showControls: showControls)

            // Build minimal HTML that uses the official IFrame API and controls playback reliably
            let controls = showControls ? 1 : 0
            let loop = 1
            let playsinline = 1
            let fs = 0
            let modest = 1
            let rel = 0
            let start = max(0, startTime)
            let auto = autoplay ? 1 : 0
            let initialMuteJS = muted ? "try{player.mute();}catch(e){}" : "try{player.unMute();}catch(e){}"
            let initialPlayJS = autoplay ? "try{player.playVideo();}catch(e){}" : ""

            let html = """
            <!DOCTYPE html>
            <html>
            <head>
              <meta name="viewport" content="initial-scale=1, maximum-scale=1, user-scalable=no, width=device-width">
              <style>
                html, body { margin:0; padding:0; background-color:#000; height:100%; overflow:hidden; }
                #player { position:absolute; top:0; left:0; width:100%; height:100%; }
              </style>
            </head>
            <body>
              <div id="player"></div>
              <script>
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                var firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
                var player;
                function onYouTubeIframeAPIReady() {
                  player = new YT.Player('player', {
                    height: '100%',
                    width: '100%',
                    videoId: '\(videoID)',
                    playerVars: {
                      'playsinline': \(playsinline),
                      'autoplay': \(auto),
                      'controls': \(controls),
                      'rel': \(rel),
                      'fs': \(fs),
                      'modestbranding': \(modest),
                      'color': 'white',
                      'loop': \(loop),
                      'playlist': '\(videoID)',
                      'start': \(start)
                    },
                    events: {
                      'onReady': onPlayerReady
                    }
                  });
                }
                function onPlayerReady(event) {
                  \(initialMuteJS)
                  \(initialPlayJS)
                }
              </script>
            </body>
            </html>
            """

            webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
        }

        private func ensureAudioSessionIfNeeded(autoplay: Bool, muted: Bool, showControls: Bool) {
            // Only try to start audio session for cases that might need it (e.g. trailer with controls)
            guard autoplay, showControls, !muted else { return }
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("AudioSession activation failed: \(error)")
            }
        }
    }
}

#Preview("YouTubePlayerView - Trailer (Autoplay with Audio)") {
    YouTubePlayerView(videoID: "dQw4w9WgXcQ", autoplay: true, startTime: 0, muted: false, showControls: true)
        .frame(height: 260)
        .background(Color.black)
        .preferredColorScheme(.dark)
}

#Preview("YouTubePlayerView - Shorts (Muted Autoplay)") {
    YouTubePlayerView(videoID: "dQw4w9WgXcQ", autoplay: true, startTime: 0, muted: true, showControls: false)
        .frame(height: 260)
        .background(Color.black)
        .preferredColorScheme(.dark)
}