import SwiftUI

struct TrailerPlayerView: View {
    let trailerURLString: String
    let onClose: () -> Void
    
    private var videoID: String? {
        Self.youtubeID(from: trailerURLString)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            
            if let id = videoID {
                VStack(spacing: 0) {
                    YouTubePlayerView(videoID: id, autoplay: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.yellow)
                    Text("Trailer unavailable")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.12), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .padding(16)
            }
        }
        .statusBarHidden(true)
    }
    
    static func youtubeID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        if let host = url.host, host.contains("youtu.be") {
            return url.lastPathComponent
        }
        if let host = url.host, host.contains("youtube.com") {
            if let query = url.query {
                for part in query.components(separatedBy: "&") {
                    let kv = part.components(separatedBy: "=")
                    if kv.count == 2, kv[0] == "v" { return kv[1] }
                }
            }
            let comps = url.pathComponents
            if let idx = comps.firstIndex(of: "embed"), idx + 1 < comps.count {
                return comps[idx + 1]
            }
        }
        return nil
    }
}

#Preview("TrailerPlayerView") {
    TrailerPlayerView(trailerURLString: "https://www.youtube.com/watch?v=dQw4w9WgXcQ") { }
        .preferredColorScheme(.dark)
}