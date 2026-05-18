#if canImport(SwiftSoup)
import SwiftSoup
#endif
import Foundation

/// Parses HTML in video descriptions into plain text and structured links.
struct HTMLDescriptionParser {

    struct ParsedDescription {
        let plainText: String
        let links: [DescriptionLink]
        let hashtags: [String]
        let timestamps: [VideoTimestamp]
    }

    struct DescriptionLink: Identifiable {
        let id = UUID()
        let text: String
        let url: URL
    }

    struct VideoTimestamp: Identifiable {
        let id = UUID()
        let label: String
        let seconds: Int
    }

    static func parse(_ rawText: String) -> ParsedDescription {
        var plainText = rawText
        var links: [DescriptionLink] = []

        #if canImport(SwiftSoup)
        if let doc = try? SwiftSoup.parse(rawText) {
            plainText = (try? doc.text()) ?? rawText
            if let anchors = try? doc.select("a") {
                for anchor in anchors {
                    let text = (try? anchor.text()) ?? ""
                    let href = (try? anchor.attr("href")) ?? ""
                    if let url = URL(string: href) {
                        links.append(DescriptionLink(text: text, url: url))
                    }
                }
            }
        }
        #endif

        let hashtags = plainText.components(separatedBy: .whitespaces)
            .filter { $0.hasPrefix("#") }
            .map { String($0.dropFirst()) }

        let timestamps = extractTimestamps(from: plainText)

        return ParsedDescription(
            plainText: plainText,
            links: links,
            hashtags: hashtags,
            timestamps: timestamps
        )
    }

    static func stripHTML(_ html: String) -> String {
        #if canImport(SwiftSoup)
        return (try? SwiftSoup.parse(html).text()) ?? html
        #else
        return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        #endif
    }

    private static func extractTimestamps(from text: String) -> [VideoTimestamp] {
        let pattern = #"(\d{1,2}:\d{2}(?::\d{2})?)\s+(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { match -> VideoTimestamp? in
            guard let timeRange = Range(match.range(at: 1), in: text),
                  let labelRange = Range(match.range(at: 2), in: text) else { return nil }
            let timeStr = String(text[timeRange])
            let label = String(text[labelRange])
            let parts = timeStr.split(separator: ":").compactMap { Int($0) }
            let seconds: Int
            if parts.count == 3 { seconds = parts[0] * 3600 + parts[1] * 60 + parts[2] }
            else if parts.count == 2 { seconds = parts[0] * 60 + parts[1] }
            else { return nil }
            return VideoTimestamp(label: label, seconds: seconds)
        }
    }
}
