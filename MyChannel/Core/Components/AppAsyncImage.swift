import SwiftUI
import UIKit

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
                    .task(id: url) {
                        await load()
                    }
            }
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
                await MainActor.run { self.uiImage = image }
            }
            return
        }

        if url.isFileURL {
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                await MainActor.run { self.uiImage = img }
            }
            return
        }

        if let name = assetName(from: url), let img = UIImage(named: name) {
            await MainActor.run { self.uiImage = img }
            return
        }

        if inPreviews() {
            // Try fast real fetch; fallback to generated image
            if let fetched = await tryFetch(url: url, timeout: 2.5) {
                await MainActor.run { self.uiImage = fetched }
                return
            } else {
                let image = generatePreviewImage(size: thumbnailTargetSize())
                await MainActor.run { self.uiImage = image }
                return
            }
        }

        if let fetched = await tryFetch(url: url, timeout: 12.0) {
            await MainActor.run { self.uiImage = fetched }
        }
    }

    private func tryFetch(url: URL, timeout: TimeInterval) async -> UIImage? {
        var config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForResource = timeout
        config.timeoutIntervalForRequest = timeout
        // Ensure no lingering preview protocol classes intercept
        if let anyStub = NSClassFromString("PreviewImageURLProtocol") {
            config.protocolClasses = (config.protocolClasses ?? []).filter { $0 != anyStub }
        }
        if let bundleName = Bundle.main.infoDictionary?["CFBundleName"] as? String,
           let namespacedStub = NSClassFromString("\(bundleName).PreviewImageURLProtocol") {
            config.protocolClasses = (config.protocolClasses ?? []).filter { $0 != namespacedStub }
        }

        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { return nil }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    private func assetName(from url: URL) -> String? {
        guard url.scheme == "asset" else { return nil }
        if let host = url.host, !host.isEmpty { return host }
        let p = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return p.isEmpty ? nil : p
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