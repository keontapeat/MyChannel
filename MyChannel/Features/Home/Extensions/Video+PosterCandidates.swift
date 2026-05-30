import Foundation

extension Video {
    var posterCandidates: [URL] {
        var urls: [URL] = []
        var seen = Set<String>()

        func add(_ s: String) {
            if !s.isEmpty, seen.insert(s).inserted, let u = URL(string: s) {
                urls.append(u)
            }
        }

        // 1) Use provided thumbnail if present
        add(thumbnailURL)

        // 2) Prefer YouTube covers when applicable
        if contentSource == .youtube {
            let yid = externalID.flatMap { $0.isEmpty ? nil : $0 } ?? id
            // Common JPG candidates
            add("https://i.ytimg.com/vi/\(yid)/maxresdefault.jpg")
            add("https://i.ytimg.com/vi/\(yid)/sddefault.jpg")
            add("https://i.ytimg.com/vi/\(yid)/hqdefault.jpg")
            add("https://img.youtube.com/vi/\(yid)/maxresdefault.jpg")
            add("https://img.youtube.com/vi/\(yid)/sddefault.jpg")
            add("https://img.youtube.com/vi/\(yid)/hqdefault.jpg")
            // Frame indices
            add("https://img.youtube.com/vi/\(yid)/0.jpg")
            add("https://img.youtube.com/vi/\(yid)/1.jpg")
            add("https://img.youtube.com/vi/\(yid)/2.jpg")
            add("https://img.youtube.com/vi/\(yid)/3.jpg")
            // WEBP variants
            add("https://i.ytimg.com/vi_webp/\(yid)/maxresdefault.webp")
            add("https://i.ytimg.com/vi_webp/\(yid)/sddefault.webp")
            add("https://i.ytimg.com/vi_webp/\(yid)/hqdefault.webp")
        }

        // 3) Seeded fallback to guarantee an image
        add("https://picsum.photos/seed/\(abs(id.hashValue))/400/225")

        return urls
    }
}
