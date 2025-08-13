import Foundation

// Centralized, secure secrets access.
// Order: Info.plist resolved value (not placeholders) -> Environment variable -> empty.
struct AppSecrets {
    static var tmdbAPIKey: String {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "TMDB_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }

        let env = (ProcessInfo.processInfo.environment["TMDB_API_KEY"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !env.isEmpty { return env }

        return ""
    }

    static var pexelsAPIKey: String {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "PEXELS_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return ProcessInfo.processInfo.environment["PEXELS_API_KEY"] ?? ""
    }

    static var pixabayAPIKey: String {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "PIXABAY_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return ProcessInfo.processInfo.environment["PIXABAY_API_KEY"] ?? ""
    }

    static var youtubeAPIKey: String {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return (ProcessInfo.processInfo.environment["YOUTUBE_API_KEY"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var isPlistPlaceholder: Bool {
        // Xcode leaves $(VAR) or ${VAR} unresolved if no value is provided at build time
        contains("$(") || contains("${")
    }
}