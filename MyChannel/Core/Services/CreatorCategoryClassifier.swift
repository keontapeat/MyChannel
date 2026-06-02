//
//  CreatorCategoryClassifier.swift
//  MyChannel
//
//  🧠 AI-POWERED CREATOR CATEGORY DETECTION
//  ─────────────────────────────────────────────────────────────────
//  Decides whether a real user belongs in Top Artists, Top Indie
//  Filmmakers, or Top MyChannels — exactly like a YouTube ranking
//  engineer would classify a channel before slotting it into a shelf.
//
//  Strategy (cheap → smart):
//   1. Explicit signal: user already has creatorCategory written.
//   2. Heuristic signal: bio keywords + the categories of their uploads.
//   3. AI signal: Claude classifies ambiguous creators from their
//      bio + recent video titles, then we persist the result so we
//      never have to pay for the call twice.
//
//  The resolved category is written back to the user's Firestore doc
//  under `creatorCategory`, so TopRankMLService.resolveCategory() picks
//  it up instantly on the next ranking cycle and it syncs across
//  devices.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class CreatorCategoryClassifier: ObservableObject {

    static let shared = CreatorCategoryClassifier()
    private init() {}

    /// In-memory cache so we never re-classify the same uid in a session.
    private var cache: [String: RankCategory] = [:]
    /// uids we're currently classifying, to avoid duplicate AI calls.
    private var inFlight: Set<String> = []

    // MARK: - Keyword dictionaries (fast local signal)

    private static let artistKeywords = [
        "artist", "music", "musician", "rapper", "rap", "singer", "song",
        "producer", "beats", "dj", "vocalist", "band", "album", "mixtape",
        "studio", "record", "hip hop", "hip-hop", "r&b", "rnb", "trap"
    ]
    private static let filmmakerKeywords = [
        "film", "filmmaker", "movie", "director", "cinema", "cinematograph",
        "videographer", "short film", "documentary", "screenplay", "production",
        "visuals", "shot by", "shotby", "animation", "animator", "vfx", "editor"
    ]

    // MARK: - Public API

    /// Returns the best-known category synchronously (cache / explicit / heuristic),
    /// and — only for the signed-in user's own profile — kicks off AI refinement that
    /// persists the result. For other creators we classify in-memory only (no writes),
    /// because a creator's category is authoritatively decided by their own client.
    func category(
        forUserId uid: String,
        displayName: String,
        bio: String?,
        videoCategories: [VideoCategory] = [],
        videoTitles: [String] = []
    ) -> RankCategory {
        if let cached = cache[uid] { return cached }

        // 1. Heuristic from bio + uploaded content categories.
        if let heuristic = heuristicCategory(bio: bio, videoCategories: videoCategories) {
            cache[uid] = heuristic
            return heuristic
        }

        // 2. Ambiguous → only the owner's client runs the (paid) AI pass + persists.
        if isCurrentUser(uid) {
            scheduleAIClassification(uid: uid, displayName: displayName, bio: bio, videoTitles: videoTitles)
        }
        // Default to channel until a better signal arrives.
        return .channel
    }

    /// Authoritative self-classification — each creator categorizes THEIR OWN channel.
    /// Safe to call on profile load / app launch; it no-ops if a category is already set.
    func classifyCurrentUserIfNeeded(force: Bool = false) async {
        guard let user = AuthenticationManager.shared.currentUser else { return }
        let uid = user.id
        if !force, cache[uid] != nil { return }

        // Use the creator's own recent uploads as the strongest signal.
        let recent = await VideoFirestoreService.shared.fetchVideosByCreator(creatorId: uid, limit: 12)
        let cats = recent.map { $0.category }
        let titles = recent.map { $0.title }

        if let heuristic = heuristicCategory(bio: user.bio, videoCategories: cats) {
            await assignCategory(heuristic, toUserId: uid)
            return
        }
        let resolved = await classifyWithAI(displayName: user.displayName, bio: user.bio, videoTitles: titles)
        await assignCategory(resolved, toUserId: uid)
    }

    private func isCurrentUser(_ uid: String) -> Bool {
        AuthenticationManager.shared.currentUser?.id == uid
    }

    /// Pure heuristic classification — no network. Returns nil when ambiguous.
    func heuristicCategory(bio: String?, videoCategories: [VideoCategory]) -> RankCategory? {
        // Strongest signal: what the creator actually uploads.
        if !videoCategories.isEmpty {
            let filmmakerCats: Set<VideoCategory> = [.movies, .tvShows, .documentaries, .anime, .cartoons, .adultAnimation, .art]
            let artistCats: Set<VideoCategory> = [.music]

            let filmmakerHits = videoCategories.filter { filmmakerCats.contains($0) }.count
            let artistHits = videoCategories.filter { artistCats.contains($0) }.count

            if artistHits > 0 && artistHits >= filmmakerHits { return .artist }
            if filmmakerHits > 0 { return .filmmaker }
        }

        // Next signal: bio keywords.
        guard let bio = bio?.lowercased(), !bio.isEmpty else { return nil }
        let artistScore = Self.artistKeywords.filter { bio.contains($0) }.count
        let filmmakerScore = Self.filmmakerKeywords.filter { bio.contains($0) }.count

        if artistScore == 0 && filmmakerScore == 0 { return nil }
        if artistScore >= filmmakerScore { return .artist }
        return .filmmaker
    }

    // MARK: - AI classification (Claude) + persistence

    /// Explicitly assign + persist a category (used when we have a strong signal,
    /// e.g. the creator's own upload category). Updates the in-session cache so the
    /// ranker uses it immediately, and writes it through to Firestore for all devices.
    func assignCategory(_ category: RankCategory, toUserId uid: String) async {
        cache[uid] = category
        await persistCategory(category, forUserId: uid)
    }

    private func scheduleAIClassification(uid: String, displayName: String, bio: String?, videoTitles: [String]) {
        // Don't classify seed/friend ids (ig_/ai_/rising_) — they're pre-categorized.
        guard !uid.hasPrefix("ig_"), !uid.hasPrefix("ai_"), !uid.hasPrefix("rising_"), !uid.hasPrefix("seed_") else { return }
        guard !inFlight.contains(uid) else { return }
        inFlight.insert(uid)

        Task { [weak self] in
            guard let self else { return }
            let resolved = await self.classifyWithAI(displayName: displayName, bio: bio, videoTitles: videoTitles)
            await MainActor.run {
                self.cache[uid] = resolved
                self.inFlight.remove(uid)
            }
            // Persisting creatorCategory modifies the user doc, which the
            // TopRankMLService users-collection listener already observes and
            // re-ranks from — so the creator lands in the right shelf without us
            // firing a manual refresh per classification (avoids refresh storms).
            await self.persistCategory(resolved, forUserId: uid)
        }
    }

    private func classifyWithAI(displayName: String, bio: String?, videoTitles: [String]) async -> RankCategory {
        let titles = videoTitles.prefix(8).joined(separator: "\n- ")
        let prompt = """
        Classify this creator into EXACTLY one bucket for a video platform's "Top" shelves.

        Buckets:
        - "artist": music creators (rappers, singers, producers, DJs, bands).
        - "filmmaker": indie filmmakers, directors, videographers, animators, documentary makers.
        - "channel": everyone else (vlogs, gaming, comedy, lifestyle, sports, general content).

        Creator name: \(displayName)
        Bio: \(bio ?? "none")
        Recent video titles:
        - \(titles.isEmpty ? "none" : titles)

        Reply with ONLY one word: artist, filmmaker, or channel.
        """

        if let raw = try? await AnthropicService.shared.sendMessage(prompt, maxTokens: 8) {
            let token = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if token.contains("artist") { return .artist }
            if token.contains("filmmaker") || token.contains("film") { return .filmmaker }
            if token.contains("channel") { return .channel }
        }

        // AI unavailable → fall back to bio heuristic, else channel.
        return heuristicCategory(bio: bio, videoCategories: []) ?? .channel
    }

    private func persistCategory(_ category: RankCategory, forUserId uid: String) async {
        #if canImport(FirebaseFirestore)
        do {
            try await Firestore.firestore().collection("users").document(uid).setData([
                "creatorCategory": category.rawValue,
                "creatorCategoryUpdatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            print("🧠 [CategoryClassifier] \(uid) → \(category.rawValue)")
        } catch {
            print("⚠️ [CategoryClassifier] Failed to persist category for \(uid): \(error.localizedDescription)")
        }
        #endif
    }
}
