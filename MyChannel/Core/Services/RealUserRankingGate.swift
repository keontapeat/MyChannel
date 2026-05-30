//
//  RealUserRankingGate.swift
//  MyChannel
//
//  🏆 FAIR RANKING GATE
//  ─────────────────────────────────────────────────────────────────
//  Keeps ALL seed/friend data — nothing gets deleted.
//  As real users join and upload, their content naturally ranks
//  higher through an organic score multiplier that scales with
//  platform growth. Fair for everybody.
//
//  Multiplier logic (applied on top of base feed scores):
//
//   Real users on platform │ Seed content multiplier │ Real content multiplier
//  ─────────────────────────┼─────────────────────────┼─────────────────────────
//  0  – 9 (launch phase)   │ 1.00 (no penalty)        │ 1.20 (slight boost)
//  10 – 49 (early)         │ 0.70                     │ 1.40
//  50 – 199 (growing)      │ 0.45                     │ 1.60
//  200 – 999 (traction)    │ 0.25                     │ 1.80
//  1000+ (scale)           │ 0.10                     │ 2.00
//
//  Friends (imported) are ALWAYS treated as real regardless of
//  userType. Their content never gets penalized.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Content Origin

enum ContentOrigin {
    case real           // Uploaded by a verified real Firestore user
    case friend         // Your imported IG friends (always treated as real)
    case aiGenerated    // AI-seeded filler content
}

// MARK: - Ranking Gate

@MainActor
final class RealUserRankingGate: ObservableObject {

    static let shared = RealUserRankingGate()
    private init() {}

    // MARK: - State

    /// Current count of real registered users (pulled from Firestore, cached).
    @Published private(set) var realUserCount: Int = 0
    /// Last time we refreshed the count from Firestore.
    private var lastRefreshed: Date = .distantPast
    /// Refresh interval — check every 5 minutes at most.
    private let refreshInterval: TimeInterval = 5 * 60

    // MARK: - Refresh real user count

    /// Fetches the real user count from Firestore (with cooldown so we don't spam reads).
    func refreshIfNeeded() async {
        let now = Date()
        guard now.timeIntervalSince(lastRefreshed) > refreshInterval else { return }
        lastRefreshed = now

        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            // Count documents in the users collection (real sign-ups only).
            let snap = try await db.collection("users")
                .whereField("userType", isEqualTo: "real")
                .limit(to: 10_000)
                .getDocuments()
            realUserCount = snap.documents.count
            print("🏆 [RankingGate] Real user count refreshed: \(realUserCount)")
        } catch {
            // Fall back to AuthenticationManager head-count on error.
            realUserCount = AuthenticationManager.shared.isAuthenticated ? 1 : 0
            print("⚠️ [RankingGate] Could not fetch real user count, using fallback: \(realUserCount)")
        }
        #else
        realUserCount = AuthenticationManager.shared.isAuthenticated ? 1 : 0
        #endif
    }

    // MARK: - Multipliers

    /// Score multiplier for seed / AI-generated content.
    /// Returns 1.0 during launch phase so seed content still shows normally.
    /// Shrinks toward 0.10 as real users grow — content is pushed back, NOT deleted.
    var seedContentMultiplier: Double {
        switch realUserCount {
        case 0..<10:   return 1.00
        case 10..<50:  return 0.70
        case 50..<200: return 0.45
        case 200..<1000: return 0.25
        default:       return 0.10
        }
    }

    /// Score multiplier for content uploaded by actual real users.
    var realContentMultiplier: Double {
        switch realUserCount {
        case 0..<10:   return 1.20
        case 10..<50:  return 1.40
        case 50..<200: return 1.60
        case 200..<1000: return 1.80
        default:       return 2.00
        }
    }

    /// Friendly label for the current platform phase.
    var phaseName: String {
        switch realUserCount {
        case 0..<10:   return "Launch Phase"
        case 10..<50:  return "Early Adopters"
        case 50..<200: return "Growing"
        case 200..<1000: return "Traction"
        default:       return "Scale"
        }
    }

    // MARK: - Origin detection

    /// Determines whether a video was uploaded by a real user, a friend, or AI seed.
    func origin(of video: Video) -> ContentOrigin {
        let creatorId = video.creator.id

        // Friends always rank as real — never penalized.
        if creatorId.hasPrefix("ig_") {
            return .friend
        }

        // AI-seeded filler content.
        if creatorId.hasPrefix("ai_") || creatorId.hasPrefix("rising_") || creatorId.hasPrefix("seed_") {
            return .aiGenerated
        }

        // Anything stored in Firestore with a real UID is real.
        return .real
    }

    /// Determines whether a seeded user (from SmartUserSeederService) should be penalized.
    func origin(of seededUser: SmartUserSeederService.SeededUser) -> ContentOrigin {
        switch seededUser.userType {
        case .real:      return .real
        case .imported:  return .friend
        case .aiGenerated: return .aiGenerated
        }
    }

    // MARK: - Score application

    /// Apply the ranking gate multiplier to a raw score.
    /// - Parameters:
    ///   - rawScore: The base relevance / engagement score (0.0 – 1.0 or higher).
    ///   - video: The video being ranked.
    /// - Returns: Adjusted score. Real content rises; seed content falls back naturally.
    func adjustedScore(rawScore: Double, for video: Video) -> Double {
        switch origin(of: video) {
        case .real, .friend:
            return rawScore * realContentMultiplier
        case .aiGenerated:
            return rawScore * seedContentMultiplier
        }
    }

    // MARK: - Feed sorting

    /// Sort a mixed array of videos so real uploads naturally surface first.
    /// Seed/friend data stays in the list — just ranked lower as real users grow.
    func ranked(_ videos: [Video], baseScores: [String: Double] = [:]) -> [Video] {
        return videos.sorted { a, b in
            let scoreA = adjustedScore(rawScore: baseScores[a.id] ?? defaultScore(a), for: a)
            let scoreB = adjustedScore(rawScore: baseScores[b.id] ?? defaultScore(b), for: b)
            return scoreA > scoreB
        }
    }

    /// Sort a mixed list of seeded users so real profiles surface first.
    func ranked(_ users: [SmartUserSeederService.SeededUser]) -> [SmartUserSeederService.SeededUser] {
        return users.sorted { a, b in
            let scoreA = userScore(a)
            let scoreB = userScore(b)
            return scoreA > scoreB
        }
    }

    // MARK: - Private helpers

    /// Default engagement score for a video when no explicit score is provided.
    private func defaultScore(_ video: Video) -> Double {
        let popularity = min(Double(video.viewCount) / 1_000_000, 0.5)
        let engagement = min(Double(video.likeCount) / 100_000, 0.3)
        let recency = max(0, 0.2 - Date().timeIntervalSince(video.createdAt) / (30 * 24 * 3600))
        return popularity + engagement + recency
    }

    /// Engagement score for a seeded user profile.
    private func userScore(_ user: SmartUserSeederService.SeededUser) -> Double {
        let baseScore = Double(user.subscriberCount) / 100_000
            + Double(user.totalViews) / 1_000_000
        let multiplier: Double
        switch origin(of: user) {
        case .real, .friend: multiplier = realContentMultiplier
        case .aiGenerated:   multiplier = seedContentMultiplier
        }
        return baseScore * multiplier
    }
}
