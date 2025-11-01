import Foundation

@MainActor
final class RemoteConfigService: ObservableObject {
    static let shared = RemoteConfigService()
    private init() {}

    func int(forKey key: String, default defaultValue: Int) -> Int {
        if let v = UserDefaults.standard.object(forKey: "rc_\(key)") as? Int { return v }
        return defaultValue
    }

    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if let v = UserDefaults.standard.object(forKey: "rc_\(key)") as? Bool { return v }
        return defaultValue
    }
}




