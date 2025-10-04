import Foundation
import SwiftUI

// Fetches legal, public IPTV catalogs from iptv-org and converts to LiveTVChannel.
// Uses LiveStreamHealthChecker to rank healthy HLS streams.
final class IPTVOrgService {
    static let shared = IPTVOrgService()
    private init() {}

    private struct ChannelDTO: Decodable {
        let id: String
        let name: String
        let logo: String?
        let country: String?
        let languages: [String]?
        let categories: [String]?
        let city: String?
    }

    private struct StreamDTO: Decodable {
        let channel: String
        let url: String
        let status: String?
        let http_referrer: String?
        let user_agent: String?
    }

    private let channelsURL = URL(string: "https://iptv-org.github.io/api/channels.json")!
    private let streamsURL  = URL(string: "https://iptv-org.github.io/api/streams.json")!

    private var cache: [LiveTVChannel] = []
    private var cacheTime: Date = .distantPast
    private let cacheTTL: TimeInterval = 60 * 30 // 30 minutes

    func fetchTopChannels(
        limit: Int = 24,
        countries: [String]? = ["US", "GB", "CA"],
        languages: [String]? = ["eng"],
        categories filterCats: [String]? = nil
    ) async -> [LiveTVChannel] {
        if Date().timeIntervalSince(cacheTime) < cacheTTL, !cache.isEmpty {
            return Array(cache.prefix(limit))
        }

        do {
            let (channels, streams) = try await (
                fetchJSON([ChannelDTO].self, from: channelsURL),
                fetchJSON([StreamDTO].self, from: streamsURL)
            )

            let streamMap = Dictionary(grouping: streams.filter { s in
                let u = s.url.lowercased()
                return u.hasPrefix("http") && (u.contains(".m3u8") || u.contains("m3u8?"))
            }) { $0.channel }

            var mapped: [LiveTVChannel] = []

            for ch in channels {
                // Country/language/category filtering
                if let countries, let code = ch.country, !countries.contains(code) { continue }
                if let languages, let langs = ch.languages, !langs.contains(where: { languages.contains($0) }) { continue }
                if let filterCats, let cats = ch.categories, !cats.contains(where: { c in filterCats.contains(where: { c.caseInsensitiveCompare($0) == .orderedSame }) }) {
                    continue
                }

                guard let s = streamMap[ch.id]?.first else { continue }
                let streamURL = s.url

                let cat = chooseCategory(from: ch.categories)
                let channel = LiveTVChannel(
                    id: ch.id,
                    name: ch.name,
                    logoURL: chooseLogo(ch.logo),
                    streamURL: streamURL,
                    category: cat,
                    description: makeDescription(ch: ch),
                    isLive: true,
                    viewerCount: Int.random(in: 2_000...50_000),
                    quality: "HD",
                    language: (ch.languages?.first?.uppercased() ?? "EN"),
                    country: (ch.country ?? "INT"),
                    epgURL: nil,
                    previewFallbackURL: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
                )
                mapped.append(channel)
            }

            // Health-rank the candidates
            let healthy = await LiveStreamHealthChecker.rankHealthyChannels(mapped, timeout: 1.5)
            cache = healthy
            cacheTime = Date()
            return Array(healthy.prefix(limit))
        } catch {
            print("[IPTVOrgService] Error fetching channels: \(error)")
            return []
        }
    }

    private func fetchJSON<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.timeoutInterval = 12
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func chooseCategory(from cats: [String]?) -> LiveTVChannel.ChannelCategory {
        guard let c = cats?.first?.lowercased() else { return .international }
        if c.contains("news") { return .news }
        if c.contains("sports") { return .sports }
        if c.contains("movie") || c.contains("film") { return .movies }
        if c.contains("music") { return .music }
        if c.contains("kids") { return .kids }
        if c.contains("document") { return .documentary }
        if c.contains("life") { return .lifestyle }
        if c.contains("entertain") { return .entertainment }
        if c.contains("business") || c.contains("finance") { return .business }
        return .international
    }

    private func makeDescription(ch: ChannelDTO) -> String {
        let country = ch.country ?? "International"
        let city = ch.city.map { " • \($0)" } ?? ""
        return "\(country)\(city) • Live channel"
    }

    private func chooseLogo(_ s: String?) -> String {
        guard let s, !s.isEmpty else {
            return "https://picsum.photos/seed/\(Int.random(in: 1...99999))/320/180"
        }
        // Some logos are SVG; that’s fine – we already handle placeholder fallback elsewhere.
        return s
    }
}

#Preview("IPTVOrg fetch (names only)") {
    VStack(alignment: .leading) {
        Text("IPTVOrg Top")
            .font(.headline)
        Text("Run the app to fetch; this preview does not perform network calls.")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}