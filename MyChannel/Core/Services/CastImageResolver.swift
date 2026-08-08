import Foundation

/// Resolves cast-member names to TMDB headshot URLs, caching each lookup for the
/// process lifetime so a name is only searched once. Fails closed (returns nil)
/// when the TMDB key is absent — callers fall back to an initials avatar.
actor CastImageResolver {
    static let shared = CastImageResolver()
    private init() {}

    /// Cached results. `URL?` value of `nil` means "looked up, no headshot found",
    /// which is still cached to avoid repeat network calls.
    private var cache: [String: URL?] = [:]
    /// In-flight lookups, so concurrent cards for the same name share one request.
    private var inFlight: [String: Task<URL?, Never>] = [:]

    func profileURL(for name: String) async -> URL? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }

        if let cached = cache[key] { return cached }
        if let existing = inFlight[key] { return await existing.value }

        let task = Task<URL?, Never> { [name] in
            let urlString = await TMDBService.shared.personProfileURLString(name: name)
            return urlString.flatMap { URL(string: $0) }
        }
        inFlight[key] = task
        let resolved = await task.value
        cache[key] = resolved
        inFlight[key] = nil
        return resolved
    }
}
