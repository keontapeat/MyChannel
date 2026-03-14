import SwiftUI
import UIKit

// 🔥🔥🔥 THERMONUCLEAR CACHED ASYNC IMAGE 🔥🔥🔥
// Uses shared ImageCache with request deduplication for INSTANT loads
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url?.absoluteString) {
            await loadImage()
        }
    }
    
    @MainActor
    private func loadImage() async {
        guard let url else { return }
        
        // 🔥 INSTANT: Check cache first
        if let cachedImage = ImageCache.shared.image(for: url) {
            self.image = cachedImage
            return
        }
        
        // 🔥 Load with shared high-performance session
        do {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 8
            config.httpMaximumConnectionsPerHost = 10
            let session = URLSession(configuration: config)
            
            let (data, _) = try await session.data(from: url)
            
            // 🔥 Parse on background thread
            let uiImage = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)
            }.value
            
            if let uiImage {
                ImageCache.shared.store(uiImage, for: url)
                self.image = uiImage
            }
        } catch {
            // Silently fail - image will show placeholder
        }
    }
}