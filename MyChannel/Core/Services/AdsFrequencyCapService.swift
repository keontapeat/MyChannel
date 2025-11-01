import Foundation

@MainActor
final class AdsFrequencyCapService {
    static let shared = AdsFrequencyCapService()
    private init() {}

    private let capsKey = "ads_caps"

    struct Caps: Codable { var day: String; var prerollShown: Int; var midrollShown: Int }

    func canShowPreroll(maxPerDay: Int = 5) -> Bool {
        var caps = current()
        if caps.day != today() { caps = Caps(day: today(), prerollShown: 0, midrollShown: 0); save(caps) }
        return caps.prerollShown < maxPerDay
    }

    func recordPreroll() {
        var caps = current(); if caps.day != today() { caps = Caps(day: today(), prerollShown: 0, midrollShown: 0) }
        caps.prerollShown += 1; save(caps)
    }

    func canShowMidroll(maxPerDay: Int = 8) -> Bool {
        var caps = current()
        if caps.day != today() { caps = Caps(day: today(), prerollShown: 0, midrollShown: 0); save(caps) }
        return caps.midrollShown < maxPerDay
    }

    func recordMidroll() {
        var caps = current(); if caps.day != today() { caps = Caps(day: today(), prerollShown: 0, midrollShown: 0) }
        caps.midrollShown += 1; save(caps)
    }

    private func today() -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; return df.string(from: Date())
    }

    private func current() -> Caps {
        if let data = UserDefaults.standard.data(forKey: capsKey), let c = try? JSONDecoder().decode(Caps.self, from: data) { return c }
        return Caps(day: today(), prerollShown: 0, midrollShown: 0)
    }

    private func save(_ caps: Caps) {
        if let data = try? JSONEncoder().encode(caps) { UserDefaults.standard.set(data, forKey: capsKey) }
    }
}




