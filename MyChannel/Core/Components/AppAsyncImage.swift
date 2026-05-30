import SwiftUI
import UIKit

// 🔥🔥🔥 THERMONUCLEAR IMAGE LOADER - REQUEST DEDUPLICATION + CACHING 🔥🔥🔥
@MainActor
fileprivate final class ThermonuclearImageLoader {
    static let shared = ThermonuclearImageLoader()
    
    // 🔥 LRU cache with 150MB limit
    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 150_000_000  // 150MB
        cache.countLimit = 300
        return cache
    }()
    
    // 🔥 In-flight request deduplication
    private var inFlightRequests: [String: Task<UIImage?, Never>] = [:]
    
    // 🔥 Shared high-performance session
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = 10
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        config.urlCache = nil
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    func getCached(_ url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }
    
    func cache(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
    }
    
    func clearCache() {
        cache.removeAllObjects()
        inFlightRequests.removeAll()
    }
    
    // 🔥 Load with deduplication - same URL = same request
    func load(_ url: URL, timeout: TimeInterval = 10) async -> UIImage? {
        let key = url.absoluteString
        
        // 🔥 INSTANT: Check cache first
        if let cached = getCached(url) {
            return cached
        }
        
        // 🔥 Check if already loading - wait for existing request
        if let existing = inFlightRequests[key] {
            return await existing.value
        }
        
        // 🔥 Start new request (use browser User-Agent for Google CDN so avatars load)
        let task = Task<UIImage?, Never> {
            do {
                var request = URLRequest(url: url)
                let hostLower = url.host?.lowercased() ?? ""
                if hostLower.contains("googleusercontent.com") || hostLower.contains("ggpht.com")
                    || hostLower.contains("mzstatic.com") || hostLower.contains("apple.com")
                    || hostLower.contains("itunes.apple.com") || hostLower.contains("audio-ssl.itunes.apple.com") {
                    request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
                }
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { return nil }
                
                // 🔥 Parse and DECODE on background thread
                let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                    guard let raw = UIImage(data: data) else { return nil }
                    return raw.preparingForDisplay() ?? raw
                }.value
                
                if let image = image {
                    await MainActor.run {
                        self.cache(image, for: url)
                    }
                }
                return image
            } catch {
                return nil
            }
        }
        
        inFlightRequests[key] = task
        let result = await task.value
        inFlightRequests.removeValue(forKey: key)
        
        return result
    }
}

struct AppAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            // Reset cached image so we re-fetch for the new URL
            uiImage = nil
            await load()
        }
    }

    private func inPreviews() -> Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private func generatePreviewImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let radius = min(size.width, size.height) * 0.06
            let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            path.addClip()

            let start = CGPoint(x: 0, y: 0)
            let end = CGPoint(x: size.width, y: size.height)
            let colors = [
                UIColor(white: 0.965, alpha: 1).cgColor,
                UIColor(white: 0.90, alpha: 1).cgColor
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: start, end: end, options: [])

            let border = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            UIColor.black.withAlphaComponent(0.08).setStroke()
            border.lineWidth = 1
            border.stroke()

            let iconSize = min(size.width, size.height) * 0.22
            let iconRect = CGRect(x: (size.width - iconSize) / 2, y: (size.height - iconSize) / 2, width: iconSize, height: iconSize)
            let bg = UIBezierPath(ovalIn: iconRect.insetBy(dx: -14, dy: -14))
            UIColor.black.withAlphaComponent(0.25).setFill()
            bg.fill()

            if let play = UIImage(systemName: "play.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                play.draw(in: iconRect)
            }
        }
    }

    private func thumbnailTargetSize() -> CGSize {
        CGSize(width: 640, height: 360)
    }

    private func load() async {
        guard let url else {
            if inPreviews() {
                let image = generatePreviewImage(size: thumbnailTargetSize())
                self.uiImage = image
            }
            return
        }

        // 🔥 Check asset bundle first (instant)
        if let name = assetName(from: url), let img = UIImage(named: name) {
            self.uiImage = img
            return
        }

        // If the URL is asset:// and image wasn't found, try a fallback query parameter
        if url.scheme == "asset", let fallback = fallbackURL(from: url) {
            if let fetched = await ThermonuclearImageLoader.shared.load(fallback, timeout: 12.0) {
                self.uiImage = fetched
                return
            }
        }

        if inPreviews() {
            // Try fast real fetch; fallback to generated image
            if let fetched = await ThermonuclearImageLoader.shared.load(url, timeout: 2.5) {
                self.uiImage = fetched
                return
            } else {
                let image = generatePreviewImage(size: thumbnailTargetSize())
                self.uiImage = image
                return
            }
        }

        // Support local file URLs
        if url.isFileURL {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                self.uiImage = image
                return
            }
        }

        // Apple CDN: prefer HTTPS (mzstatic sometimes returns http)
        let fetchURL: URL = {
            guard url.scheme?.lowercased() == "http", let host = url.host?.lowercased(), host.contains("mzstatic.com") else { return url }
            var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
            c?.scheme = "https"
            return c?.url ?? url
        }()

        // 🔥 THERMONUCLEAR: Use deduplicated loader with caching
        if let fetched = await ThermonuclearImageLoader.shared.load(fetchURL) {
            self.uiImage = fetched
        }
    }

    private func assetName(from url: URL) -> String? {
        guard url.scheme == "asset" else { return nil }
        if let host = url.host, !host.isEmpty { return host }
        let p = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return p.isEmpty ? nil : p
    }

    private func fallbackURL(from url: URL) -> URL? {
        guard url.scheme == "asset" else { return nil }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if let item = comps.queryItems?.first(where: { $0.name == "fallback" || $0.name == "f" }),
           let value = item.value,
           let remote = URL(string: value),
           ["http","https"].contains(remote.scheme?.lowercased() ?? "") {
            return remote
        }
        return nil
    }
}

#Preview("AppAsyncImage – Preview Mode") {
    VStack(spacing: 20) {
        AppAsyncImage(
            url: URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"),
            content: { $0.resizable().scaledToFill() },
            placeholder: {
                RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5))
            }
        )
        .frame(width: 200, height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.06), lineWidth: 1))

        Text("Thumbnails attempt real fetch in previews, with instant fallback.")
            .font(.footnote)
            .foregroundColor(.secondary)
    }
    .padding()
    .preferredColorScheme(.light)
}