//
//  SportsLiveCardsService.swift
//  MyChannel
//
//  Phase 82: Sports Live Cards.
//  Real-time score/stat overlays on live streams; feeds are rights-gated
//  (NBA/NFL/UFC/Olympics partners already wired in CloudRunService).
//

import Foundation

enum SportsLeague: String, Codable, CaseIterable {
    case nba, nfl, mlb, nhl, ufc, mls, premierLeague, uefa, olympics
}

struct SportsLiveCard: Codable, Identifiable, Equatable {
    let id: String
    let league: SportsLeague
    let streamId: String          // MyChannel stream this overlays
    let homeTeam: String
    let awayTeam: String
    let homeLogoURL: URL?
    let awayLogoURL: URL?
    let homeScore: Int
    let awayScore: Int
    let period: String            // "Q1" / "H1" / "R3" / "Final"
    let clock: String             // "07:42"
    let status: String            // "in_progress" / "halftime" / "final"
    let updatedAt: Date
}

@MainActor
final class SportsLiveCardsService: ObservableObject {
    static let shared = SportsLiveCardsService()
    private init() {}

    @Published private(set) var activeCards: [SportsLiveCard] = []

    // MARK: - Fetch

    /// Fetch the latest card snapshot for a given stream. Backend routes to
    /// the partnership agent (NBA/NFL/UFC/etc.) behind the right license.
    func card(forStream streamId: String, league: SportsLeague) async throws -> SportsLiveCard? {
        guard AppConfig.Features.enableSportsLiveCards else { return nil }

        let service: CloudRunService = {
            switch league {
            case .nba: return .nbAI
            case .nfl: return .nflAI
            case .ufc: return .ufcAI
            case .olympics: return .olympicsAI
            case .premierLeague: return .premierLeagueAI
            default: return .myChannelSportsAI
            }
        }()

        struct Request: Encodable { let task: String; let streamId: String; let league: String }
        struct Raw: Decodable {
            let id: String?
            let home_team: String?
            let away_team: String?
            let home_logo_url: String?
            let away_logo_url: String?
            let home_score: Int?
            let away_score: Int?
            let period: String?
            let clock: String?
            let status: String?
        }

        let r: Raw = try await CloudRunAgentRouter.post(
            service,
            path: "/predict",
            body: Request(task: "live_card", streamId: streamId, league: league.rawValue)
        )
        guard let id = r.id else { return nil }
        let card = SportsLiveCard(
            id: id,
            league: league,
            streamId: streamId,
            homeTeam: r.home_team ?? "",
            awayTeam: r.away_team ?? "",
            homeLogoURL: r.home_logo_url.flatMap(URL.init),
            awayLogoURL: r.away_logo_url.flatMap(URL.init),
            homeScore: r.home_score ?? 0,
            awayScore: r.away_score ?? 0,
            period: r.period ?? "",
            clock: r.clock ?? "",
            status: r.status ?? "in_progress",
            updatedAt: Date()
        )

        // Replace or append in active set.
        if let idx = activeCards.firstIndex(where: { $0.streamId == streamId }) {
            activeCards[idx] = card
        } else {
            activeCards.append(card)
        }
        return card
    }

    /// Poll loop helper. Caller starts/stops via a Task.
    func pollCard(forStream streamId: String, league: SportsLeague, every seconds: TimeInterval = 5) async {
        while !Task.isCancelled {
            _ = try? await card(forStream: streamId, league: league)
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    }
}
