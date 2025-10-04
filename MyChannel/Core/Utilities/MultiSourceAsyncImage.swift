import SwiftUI

struct MultiSourceAsyncImage<Content: View, Placeholder: View>: View {
    let urls: [URL]
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var index: Int = 0
    @State private var isLoading = false
    
    init(
        urls: [URL],
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urls = urls
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear { loadIfNeeded() }
            }
        }
    }
    
    private func loadIfNeeded() {
        guard image == nil, !isLoading else { return }
        loadCurrentOrNext()
    }
    
    private func loadCurrentOrNext() {
        guard index < urls.count else { return }
        let url = urls[index]
        
        if let cached = ImageCache.shared.image(for: url) {
            self.image = cached
            return
        }
        
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                    await tryNext()
                    return
                }
                if let ui = UIImage(data: data) {
                    ImageCache.shared.setImage(ui, for: url)
                    await MainActor.run { self.image = ui }
                } else {
                    await tryNext()
                }
            } catch {
                await tryNext()
            }
        }
    }
    
    @MainActor
    private func tryNext() async {
        index += 1
        isLoading = false
        if index < urls.count {
            loadCurrentOrNext()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        MultiSourceAsyncImage(
            urls: [
                URL(string: "https://invalid.example.com/x.png")!,
                URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")!
            ],
            content: { $0.resizable().scaledToFill() },
            placeholder: {
                Rectangle().fill(Color.gray.opacity(0.25)).shimmer(active: true)
            }
        )
        .frame(width: 160, height: 240)
        .clipped()
        .cornerRadius(12)
    }
    .padding()
    .background(AppTheme.Colors.background)
}