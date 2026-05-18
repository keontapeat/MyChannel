import Foundation

@MainActor
final class LiveTVLibraryStore: ObservableObject {
    static let shared = LiveTVLibraryStore()

    @Published private(set) var savedChannelIds: Set<String> = []
    @Published private(set) var dvrChannelIds: Set<String> = []

    private let savedKey = "live_tv_saved_channel_ids"
    private let dvrKey = "live_tv_dvr_channel_ids"

    private init() {
        savedChannelIds = Set(UserDefaults.standard.stringArray(forKey: savedKey) ?? [])
        dvrChannelIds = Set(UserDefaults.standard.stringArray(forKey: dvrKey) ?? [])
    }

    func isSaved(_ channel: LiveTVChannel) -> Bool {
        savedChannelIds.contains(channel.id)
    }

    func isDVRAdded(_ channel: LiveTVChannel) -> Bool {
        dvrChannelIds.contains(channel.id)
    }

    func toggleSaved(_ channel: LiveTVChannel) {
        if savedChannelIds.contains(channel.id) {
            savedChannelIds.remove(channel.id)
        } else {
            savedChannelIds.insert(channel.id)
        }
        persist()
    }

    func toggleDVR(_ channel: LiveTVChannel) {
        if dvrChannelIds.contains(channel.id) {
            dvrChannelIds.remove(channel.id)
        } else {
            dvrChannelIds.insert(channel.id)
            savedChannelIds.insert(channel.id)
        }
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(savedChannelIds), forKey: savedKey)
        UserDefaults.standard.set(Array(dvrChannelIds), forKey: dvrKey)
    }
}

struct LiveTVProgram: Identifiable, Hashable {
    let id: String
    let channelId: String
    let title: String
    let subtitle: String
    let startDate: Date
    let endDate: Date
    let isLive: Bool

    var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
}

enum LiveTVProgramGuide {
    static func programs(for channel: LiveTVChannel, referenceDate: Date = Date()) -> [LiveTVProgram] {
        let calendar = Calendar.current
        let hourStart = calendar.dateInterval(of: .hour, for: referenceDate)?.start ?? referenceDate
        return (-1...3).map { offset in
            let start = calendar.date(byAdding: .minute, value: offset * 30, to: hourStart) ?? referenceDate
            let end = calendar.date(byAdding: .minute, value: 30, to: start) ?? referenceDate
            return LiveTVProgram(
                id: "\(channel.id)-\(offset)-\(Int(start.timeIntervalSince1970))",
                channelId: channel.id,
                title: title(for: channel, offset: offset),
                subtitle: subtitle(for: channel),
                startDate: start,
                endDate: end,
                isLive: start <= referenceDate && end > referenceDate
            )
        }
    }

    private static func title(for channel: LiveTVChannel, offset: Int) -> String {
        if offset == 0 { return "Live Now: \(channel.name)" }
        if offset < 0 { return "Previously on \(channel.name)" }
        switch channel.category {
        case .news: return "Top Stories"
        case .sports: return "Live SportsCenter"
        case .movies: return "Feature Presentation"
        case .kids: return "Family Block"
        case .music: return "Music Video Mix"
        case .documentary: return "Deep Dive"
        case .anime: return "Anime Marathon"
        case .comedy: return "Comedy Block"
        case .business: return "Market Watch"
        case .international: return "World Report"
        case .scifi: return "Sci‑Fi Hour"
        case .reality: return "Reality Picks"
        case .classic: return "Classic TV Hour"
        case .entertainment, .lifestyle: return "Up Next"
        }
    }

    private static func subtitle(for channel: LiveTVChannel) -> String {
        "\(channel.category.displayName) • \(channel.quality) • \(channel.language)"
    }
}
