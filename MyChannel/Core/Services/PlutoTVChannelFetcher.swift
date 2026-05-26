//
//  PlutoTVChannelFetcher.swift
//  MyChannel
//
//  Created by AI Assistant on 12/20/24.
//
//  🔥 Dynamic Pluto TV Channel Fetcher
//  Fetches the latest channel IDs from Pluto TV's API to ensure streams work

import Foundation

/// Fetches and caches fresh Pluto TV channel data
@MainActor
final class PlutoTVChannelFetcher: ObservableObject {
    static let shared = PlutoTVChannelFetcher()
    
    @Published private(set) var isLoading = false
    @Published private(set) var lastFetchDate: Date?
    @Published private(set) var cachedChannels: [String: PlutoChannelInfo] = [:]
    
    private let cacheKey = "pluto_tv_channels_cache"
    private let cacheDurationHours: Double = 6 // Refresh every 6 hours
    
    struct PlutoChannelInfo: Codable {
        let id: String
        let name: String
        let slug: String
        let isActive: Bool
    }
    
    private init() {
        loadFromCache()
    }
    
    // MARK: - Public API
    
    /// Get the channel ID for a show name, fetching from API if needed
    func getChannelId(for showName: String) async -> String? {
        // First check cache
        let normalizedName = showName.lowercased().replacingOccurrences(of: " ", with: "-")
        if let cached = cachedChannels[normalizedName], cached.isActive {
            return cached.id
        }
        
        // If cache is stale, refresh
        if shouldRefreshCache() {
            await fetchChannels()
        }
        
        // Check again after potential refresh
        return cachedChannels[normalizedName]?.id
    }
    
    /// Check if a channel ID is likely still valid
    func isChannelValid(_ channelId: String) async -> Bool {
        // Quick HEAD request to check if stream exists
        let urlString = "https://service-stitcher.clusters.pluto.tv/stitch/hls/channel/\(channelId)/master.m3u8?deviceType=web&deviceMake=web&deviceModel=web"
        guard let url = URL(string: urlString) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (_, response) = try await URLSession.configured.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...399).contains(httpResponse.statusCode)
            }
        } catch {
            print("⚠️ [PlutoTV] Channel validation failed for \(channelId): \(error.localizedDescription)")
        }
        return false
    }
    
    /// Force refresh channel data
    func refreshChannels() async {
        await fetchChannels()
    }
    
    // MARK: - Private Methods
    
    private func shouldRefreshCache() -> Bool {
        guard let lastFetch = lastFetchDate else { return true }
        let hoursSinceLastFetch = Date().timeIntervalSince(lastFetch) / 3600
        return hoursSinceLastFetch > cacheDurationHours
    }
    
    private func fetchChannels() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        // Pluto TV's channel guide API
        let apiURL = "https://api.pluto.tv/v2/channels?include=categories&sort=popularity:desc"
        
        guard let url = URL(string: apiURL) else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.configured.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("⚠️ [PlutoTV] API returned non-200 status")
                return
            }
            
            // Parse the response
            if let channels = try? JSONDecoder().decode([PlutoAPIChannel].self, from: data) {
                var newCache: [String: PlutoChannelInfo] = [:]
                
                for channel in channels {
                    let slug = channel.slug ?? channel.name.lowercased().replacingOccurrences(of: " ", with: "-")
                    let info = PlutoChannelInfo(
                        id: channel._id,
                        name: channel.name,
                        slug: slug,
                        isActive: true
                    )
                    newCache[slug] = info
                    // Also cache by normalized name
                    let normalizedName = channel.name.lowercased().replacingOccurrences(of: " ", with: "-")
                    if normalizedName != slug {
                        newCache[normalizedName] = info
                    }
                }
                
                cachedChannels = newCache
                lastFetchDate = Date()
                saveToCache()
                
                print("✅ [PlutoTV] Fetched \(channels.count) channels")
            }
        } catch {
            print("⚠️ [PlutoTV] Failed to fetch channels: \(error.localizedDescription)")
        }
    }
    
    private func loadFromCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(CachedData.self, from: data) {
            cachedChannels = cached.channels
            lastFetchDate = cached.fetchDate
            print("📦 [PlutoTV] Loaded \(cached.channels.count) channels from cache")
        }
    }
    
    private func saveToCache() {
        let cached = CachedData(channels: cachedChannels, fetchDate: lastFetchDate ?? Date())
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
    
    private struct CachedData: Codable {
        let channels: [String: PlutoChannelInfo]
        let fetchDate: Date
    }
    
    private struct PlutoAPIChannel: Codable {
        let _id: String
        let name: String
        let slug: String?
    }
}

// MARK: - Channel Verification Extension

extension LiveTVChannel {
    /// Verify this channel's stream is working
    func verifyStream() async -> Bool {
        await PlutoTVChannelFetcher.shared.isChannelValid(
            extractChannelId(from: streamURL) ?? ""
        )
    }
    
    /// Extract the Pluto channel ID from a stream URL
    private func extractChannelId(from url: String) -> String? {
        // URL format: .../channel/{ID}/master.m3u8...
        guard let range = url.range(of: "/channel/"),
              let endRange = url.range(of: "/master.m3u8") else {
            return nil
        }
        let startIndex = range.upperBound
        let endIndex = endRange.lowerBound
        return String(url[startIndex..<endIndex])
    }
}



