import Foundation

struct VASTAdMedia {
    let mediaURL: String
    let clickThroughURL: String?
    let durationSeconds: Int?
}

enum VASTParser {
    static func parse(xmlData: Data) -> VASTAdMedia? {
        // Minimal extraction for MP4 media files and clickThrough
        guard let xml = String(data: xmlData, encoding: .utf8) else { return nil }
        // Find MediaFile with mp4
        if let media = firstMatch(in: xml, pattern: "<MediaFile[^>]*>(.*?)</MediaFile>")?.replacingOccurrences(of: "&amp;", with: "&"),
           media.contains(".mp4") {
            let click = firstMatch(in: xml, pattern: "<ClickThrough>(.*?)</ClickThrough>")
            let durStr = firstMatch(in: xml, pattern: "<Duration>(.*?)</Duration>")
            let duration = durStr.flatMap { parseClockTime($0) }
            return VASTAdMedia(mediaURL: media, clickThroughURL: click, durationSeconds: duration)
        }
        return nil
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        let ns = text as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return nil }
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        if m.numberOfRanges >= 2 { return ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines) }
        return nil
    }

    private static func parseClockTime(_ s: String) -> Int? {
        // Format HH:MM:SS or MM:SS
        let parts = s.split(separator: ":").map { String($0) }
        guard !parts.isEmpty else { return nil }
        if parts.count == 3, let h = Int(parts[0]), let m = Int(parts[1]), let sec = Int(parts[2]) { return h*3600 + m*60 + sec }
        if parts.count == 2, let m = Int(parts[0]), let sec = Int(parts[1]) { return m*60 + sec }
        return nil
    }
}


