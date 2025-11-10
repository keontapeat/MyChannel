import SwiftUI
import UIKit

// MARK: - Cached AsyncImage for Performance
// Note: ImageCache is defined in ImagePrefetcher.swift to avoid duplication
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
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
                    .onAppear(perform: loadImage)
                    .onChange(of: url?.absoluteString) { _ in
                        // Reload when URL changes
                        image = nil
                        isLoading = false
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url, !isLoading else { return }
        
        // Check cache first
        if let cachedImage = ImageCache.shared.image(for: url) {
            self.image = cachedImage
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    ImageCache.shared.store(uiImage, for: url)
                    await MainActor.run {
                        self.image = uiImage
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run { isLoading = false }
                }
            } catch {
                print("Error loading image from \(url): \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}