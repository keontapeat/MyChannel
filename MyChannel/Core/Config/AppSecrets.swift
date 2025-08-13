import Foundation

extension String {
    var isPlistPlaceholder: Bool { contains("$(") || contains("${") }
}

// Centralized secrets access. Reads from Info.plist first, then falls back to env vars.
// Do NOT commit real keys to source control. Prefer setting via Build Settings/xcconfig or CI.
struct AppSecrets {
    static var tmdbAPIKey: String {
        let plistValue = (Bundle.main.object(forInfoDictionaryKey: "TMDB_API_KEY") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !plistValue.isEmpty, !plistValue.isPlistPlaceholder { return plistValue }

        let env = ProcessInfo.processInfo.environment["TMDB_API_KEY"] ?? ""
        if !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return env }

        return ""
    }

    static var pexelsAPIKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "PEXELS_API_KEY") as? String, !key.isEmpty, !key.isPlistPlaceholder {
            return key
        }
        return ProcessInfo.processInfo.environment["PEXELS_API_KEY"] ?? ""
    }

    static var pixabayAPIKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "PIXABAY_API_KEY") as? String, !key.isEmpty, !key.isPlistPlaceholder {
            return key
        }
        return ProcessInfo.processInfo.environment["PIXABAY_API_KEY"] ?? ""
    }
}